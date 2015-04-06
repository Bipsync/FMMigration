#import "FMMigrationManager.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMMigration.h"

@interface FMMigrationManager ()

@property (nonatomic, strong) NSString *databasePath;
@property (nonatomic, strong) NSString *migrationTableName;

@end

@implementation FMMigrationManager

static FMMigrationManager *instance = nil;

- (id)initWithDatabasePath:(NSString *)databasePath
{
    self = [super init];
    
    if (self) {
        self.databasePath = databasePath;
        self.migrationTableName = @"schema_info";
    }
    
    return self;
}

- (id)initWithDatabasePath:(NSString *)databasePath migrationTable:(NSString *)migrationTableName
{
    self = [super init];
    
    if (self) {
        self.databasePath = databasePath;
        self.migrationTableName = migrationTableName;
    }
    
    return self;
}

- (BOOL)migrateWithMigrations:(NSArray *)migrations
{
    FMDatabase *database = [FMDatabase databaseWithPath:self.databasePath];
    
    if (![database open]) {
        NSLog(@"Could not open database: %@", database.lastErrorMessage);
        return NO;
    }
    
    [self createMigrationTableWithDatabase:database];
    
    int version = [self currentVersionWithDatabase:database];
    
    if (migrations.count > version) {
        
        NSLog(@"Starting schema migration (version %d to %lu)...", version, migrations.count);
        
        BOOL fail = NO;
        
        for (int i = version; i < migrations.count && !fail; i++) {
            if (![database beginTransaction]) {
                NSLog(@"Could not begin transaction: %@", database.lastErrorMessage);
                return NO;
            }
            
            int currentVersion = i + 1;
            FMMigration *migration = [migrations objectAtIndex:i];
            
            NSMutableString *migrationLog = [NSMutableString stringWithFormat:@"Schema migration version %d...", currentVersion];
            
            NSArray *migrationSQLs = [migration upgradeWithDatabase:database];
            
            for (int j = 0; j < migrationSQLs.count && !fail; j++) {
                NSString *migrationSQL = [migrationSQLs objectAtIndex:j];
                
                if (![database executeUpdate:migrationSQL]) {
                    fail = YES;
                }
            }
            
            if (!fail) {
                NSString *increaseVersionSQL = [NSString stringWithFormat:@"UPDATE %@ SET version = ?", self.migrationTableName];
                
                if (![database executeUpdate:increaseVersionSQL, [NSNumber numberWithInt:currentVersion]]) {
                    fail = YES;
                }
                
                if (!fail && ![database commit]) {
                    fail = YES;
                }
            }
            
            if (fail) {
                [migrationLog appendString:@" fail. :("];
                [database rollback];
                
            } else {
                [migrationLog appendString:@" succeeded."];
            }
            
            NSLog(@"%@", migrationLog);
        }
        
        if (fail) {
            NSString *errorLog = @"";
            
            if ([database hadError]) {
                errorLog = [NSString stringWithFormat:@": %@", database.lastError];
            }
            
            NSLog(@"Could not complete schema migration%@", errorLog);
            
        } else {
            NSLog(@"Schema migration finished successfully");
        }
    }
    
    [database close];
    
    return YES;
}

- (void)createMigrationTableWithDatabase:(FMDatabase *)database
{
    if (![database tableExists:self.migrationTableName]) {
        NSString *createTableSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (version INTEGER UNIQUE DEFAULT 0)", self.migrationTableName];
        
        if (![database executeUpdate:createTableSQL]) {
            NSLog(@"Could not create migration table '%@': %@", self.migrationTableName, database.lastErrorMessage);
            
        } else {
            
            NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (version) VALUES (?)", self.migrationTableName];
            
            if (![database executeUpdate:insertSQL, 0]) {
                NSLog(@"Could not insert first record for migration table '%@': %@", self.migrationTableName, database.lastErrorMessage);
            }
        }
    }
}

- (int)currentVersionWithDatabase:(FMDatabase *)database
{
    int version = -1;
    
    NSString *selectSQL = [NSString stringWithFormat:@"SELECT version FROM %@", self.migrationTableName];
    version = [database intForQuery:selectSQL];
    
    return version;
}

- (NSString *)sqlForTable:(NSString *)tableName database:(FMDatabase *)database
{
    NSString *sql = [database stringForQuery:@"SELECT sql FROM sqlite_master WHERE type = ? AND tbl_name = ?", @"table", tableName];
    
    return sql;
}

- (NSString *)allColumnSQLsForSQL:(NSString *)sql
{
    NSRegularExpression *columnsRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\()((.|\\s)+)(\\))" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSTextCheckingResult *columnMatch = [[columnsRegex matchesInString:sql options:0 range:NSMakeRange(0, [sql length])] objectAtIndex:0];
    
    return [sql substringWithRange:[columnMatch rangeAtIndex:2]];
}

- (NSArray *)specialNamesForColumn
{
    return [NSArray arrayWithObjects:@"PRIMARY", @"CONSTRAINT", @"UNIQUE", @"CHECK", @"FOREIGN", nil];
}

- (NSString *)columnNameForString:(NSString *)string
{
    NSRegularExpression *columnNameRegex = [NSRegularExpression regularExpressionWithPattern:@"((\\w)+)" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSTextCheckingResult *columnNameMatch = [[columnNameRegex matchesInString:string options:0 range:NSMakeRange(0, [string length])] objectAtIndex:0];
    
    return [string substringWithRange:columnNameMatch.range];
}

#pragma mark - SQL operations

- (FMMigration *)executeSQL:(NSString *)sql
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [[NSArray alloc] initWithObjects:sql, nil];
    }];
    
    return migration;
}

- (FMMigration *)createTable:(NSString *)tableName primaryKey:(NSString *)primaryKey
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlsCreateTable:tableName primaryKey:primaryKey];
        
    } down:^(FMDatabase *database) {
        return [self sqlsDropTable:tableName];
    }];
    
    return migration;
}

- (NSArray *)sqlsCreateTable:(NSString *)tableName primaryKey:(NSString *)primaryKey
{
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT)", tableName, primaryKey];
    
    return [[NSArray alloc] initWithObjects:sql, nil];
}

- (FMMigration *)createTable:(NSString *)tableName columns:(NSArray *)columns
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlsCreateTable:tableName columns:columns];
        
    } down:^(FMDatabase *database) {
        return [self sqlsDropTable:tableName];
    }];
    
    return migration;
}

- (NSArray *)sqlsCreateTable:(NSString *)tableName columns:(NSArray *)columns
{
    NSMutableString *sql = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (", tableName];
    [sql appendString:[columns componentsJoinedByString:@","]];
    [sql appendString:@")"];
    
    return [[NSArray alloc] initWithObjects:sql, nil];
}

- (FMMigration *)renameTable:(NSString *)tableName to:(NSString *)newTableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlsRenameTable:tableName to:newTableName];
        
    } down:^(FMDatabase *database) {
        return [self sqlsRenameTable:newTableName to:tableName];
    }];
    
    return migration;
}

- (NSArray *)sqlsRenameTable:(NSString *)tableName to:(NSString *)newTableName
{
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", tableName, newTableName];
    
    return [[NSArray alloc] initWithObjects:sql, nil];
}

- (FMMigration *)dropTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlsDropTable:tableName];
        
    }];
    
    return migration;
}

- (NSArray *)sqlsDropTable:(NSString *)tableName
{
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tableName];
    
    return [[NSArray alloc] initWithObjects:sql, nil];
}

- (FMMigration *)addColumn:(NSString *)column type:(NSString *)type forTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlsAddColumn:column type:(NSString *)type forTable:tableName];
        
    } down:^(FMDatabase *database) {
        return [self sqlDropColumn:column forTable:tableName database:database];
    }];
    
    return migration;
}

- (NSArray *)sqlsAddColumn:(NSString *)column type:(NSString *)type forTable:(NSString *)tableName
{
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@", tableName, [NSString stringWithFormat:@"%@ %@", column, type]];
    
    return [[NSArray alloc] initWithObjects:sql, nil];
}

- (FMMigration *)renameColumn:(NSString *)column to:(NSString *)newColumn forTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlsRenameColumn:column to:newColumn forTable:tableName database:database];
        
    } down:^(FMDatabase *database) {
        return [self sqlsRenameColumn:newColumn to:column forTable:tableName database:database];
    }];
    
    return migration;
}

- (NSArray *)sqlsRenameColumn:(NSString *)column to:(NSString *)newColumn forTable:(NSString *)tableName database:(FMDatabase *)database
{
    NSArray *sqls = [[NSArray alloc] init];
    
    NSString *tableSQL = [self sqlForTable:tableName database:database];
    
    if (tableSQL == nil) {
        NSLog(@"SQL for table '%@' not found", tableName);
        
    } else {
        
        NSString *allColumnSQLs = [self allColumnSQLsForSQL:tableSQL];
        NSArray *columnSQLs = [allColumnSQLs componentsSeparatedByString:@","];
        
        NSArray *specialNames = [self specialNamesForColumn];
        
        NSMutableArray *newColumnSQLs = [[NSMutableArray alloc] init];
        NSMutableArray *newColumnNames = [[NSMutableArray alloc] init];
        NSMutableArray *selectOldColumns = [[NSMutableArray alloc] init];
        
        unsigned long indexRename = NSNotFound;
        
        for (int i = 0; i < columnSQLs.count; i++) {
            NSString *columnSQL = [columnSQLs objectAtIndex:i];
            NSString *columnSQLTrimmed = [columnSQL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *columnName = [self columnNameForString:columnSQLTrimmed];
            
            BOOL foundSpecialName = NO;
            
            for (int j = 0; j < specialNames.count && !foundSpecialName; j++) {
                NSString *specialName = [specialNames objectAtIndex:j];
                
                if ([[columnName uppercaseString] isEqualToString:specialName]) {
                    foundSpecialName = YES;
                }
            }
            
            if (!foundSpecialName) {
                NSArray *columnComponents = [columnSQLTrimmed componentsSeparatedByString:@" "];
                NSString *columnFullName = [columnComponents objectAtIndex:0];
                
                NSString *columnName = [self columnNameForString:columnFullName];
                NSString *columnParamName = [self columnNameForString:column];
                
                if ([[columnName lowercaseString] isEqualToString:[columnParamName lowercaseString]]) {
                    indexRename = i;
                    
                    NSMutableArray *newColumnComponents = [NSMutableArray arrayWithArray:columnComponents];
                    [newColumnComponents removeObjectAtIndex:0];
                    [newColumnComponents insertObject:newColumn atIndex:0];
                    
                    [newColumnSQLs addObject:[newColumnComponents componentsJoinedByString:@" "]];
                    [newColumnNames addObject:newColumn];
                    [selectOldColumns addObject:[NSString stringWithFormat:@"%@ as %@", columnFullName, newColumn]];
                    
                } else {
                    [newColumnSQLs addObject:columnSQL];
                    [newColumnNames addObject:columnFullName];
                    [selectOldColumns addObject:columnFullName];
                }
                
            } else {
                [newColumnSQLs addObject:columnSQL];
                
            }
        }
        
        if (indexRename == NSNotFound) {
            NSLog(@"Column '%@' on table '%@' not found to rename", column, tableName);
            
        } else {
            NSString *newAllColumnSQLs = [newColumnSQLs componentsJoinedByString:@","];
            NSString *newAllColumnNames = [newColumnNames componentsJoinedByString:@","];
            NSString *selectOldColumnSQLs = [selectOldColumns componentsJoinedByString:@","];
            
            NSString *auxTableName = [NSString stringWithFormat:@"_%@_migration", tableName];
            
            sqls = [[NSArray alloc] initWithObjects:
                    [NSString stringWithFormat:@"CREATE TEMPORARY TABLE %@(%@)", auxTableName, newAllColumnSQLs],
                    [NSString stringWithFormat:@"INSERT INTO %@ SELECT %@ FROM %@", auxTableName, selectOldColumnSQLs, tableName],
                    [NSString stringWithFormat:@"DROP TABLE %@", tableName],
                    [NSString stringWithFormat:@"CREATE TABLE %@(%@)", tableName, newAllColumnSQLs],
                    [NSString stringWithFormat:@"INSERT INTO %@ SELECT %@ FROM %@", tableName, newAllColumnNames, auxTableName],
                    [NSString stringWithFormat:@"DROP TABLE %@", auxTableName], nil];
        }
    }
    
    return sqls;
}

- (FMMigration *)dropColumn:(NSString *)column forTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        return [self sqlDropColumn:column forTable:tableName database:database];
        
    }];
    
    return migration;
}

- (NSArray *)sqlDropColumn:(NSString *)column forTable:(NSString *)tableName database:(FMDatabase *)database
{
    NSArray *sqls = [[NSArray alloc] init];
    
    NSString *tableSQL = [self sqlForTable:tableName database:database];
    
    if (tableSQL == nil) {
        NSLog(@"SQL for table '%@' not found", tableName);
        
    } else {
        NSString *allColumnSQLs = [self allColumnSQLsForSQL:tableSQL];
        NSArray *columnSQLs = [allColumnSQLs componentsSeparatedByString:@","];
        
        NSArray *specialNames = [self specialNamesForColumn];
        
        NSMutableArray *newColumnNames = [[NSMutableArray alloc] init];
        
        unsigned long indexRemove = NSNotFound;
        
        for (int i = 0; i < columnSQLs.count; i++) {
            NSString *columnSQL = [columnSQLs objectAtIndex:i];
            NSString *columnSQLTrimmed = [columnSQL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *columnName = [self columnNameForString:columnSQLTrimmed];
            
            BOOL foundSpecialName = NO;
            
            for (int j = 0; j < specialNames.count && !foundSpecialName; j++) {
                NSString *specialName = [specialNames objectAtIndex:j];
                
                if ([[columnName uppercaseString] isEqualToString:specialName]) {
                    foundSpecialName = YES;
                }
            }
            
            if (!foundSpecialName) {
                NSArray *columnComponents = [columnSQLTrimmed componentsSeparatedByString:@" "];
                NSString *columnFullName = [columnComponents objectAtIndex:0];
                
                NSString *columnName = [self columnNameForString:columnFullName];
                NSString *columnParamName = [self columnNameForString:column];
                
                if ([[columnName lowercaseString] isEqualToString:[columnParamName lowercaseString]]) {
                    indexRemove = i;
                    
                } else {
                    [newColumnNames addObject:columnFullName];
                }
            }
        }
        
        if (indexRemove == NSNotFound) {
            NSLog(@"Column '%@' on table '%@' not found to drop", column, tableName);
            
        } else {
            NSMutableArray *newColumnSQLs = [NSMutableArray arrayWithArray:columnSQLs];
            [newColumnSQLs removeObjectAtIndex:indexRemove];
            
            NSString *newAllColumnSQLs = [newColumnSQLs componentsJoinedByString:@","];
            NSString *newAllColumnNames = [newColumnNames componentsJoinedByString:@","];
            
            NSString *auxTableName = [NSString stringWithFormat:@"_%@_migration", tableName];
            
            sqls = [[NSArray alloc] initWithObjects:
                    [NSString stringWithFormat:@"CREATE TEMPORARY TABLE %@(%@)", auxTableName, newAllColumnSQLs],
                    [NSString stringWithFormat:@"INSERT INTO %@ SELECT %@ FROM %@", auxTableName, newAllColumnNames, tableName],
                    [NSString stringWithFormat:@"DROP TABLE %@", tableName],
                    [NSString stringWithFormat:@"CREATE TABLE %@(%@)", tableName, newAllColumnSQLs],
                    [NSString stringWithFormat:@"INSERT INTO %@ SELECT %@ FROM %@", tableName, newAllColumnNames, auxTableName],
                    [NSString stringWithFormat:@"DROP TABLE %@", auxTableName], nil];
        }
    }
    
    return sqls;
}

@end
