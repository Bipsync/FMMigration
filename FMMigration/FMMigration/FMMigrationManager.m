#import "FMMigrationManager.h"

#import <FMDB/FMDB.h>
#import <sqlite3.h>
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
    return [self migrateWithMigrations:migrations flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE];
}

- (BOOL)migrateWithMigrations:(NSArray *)migrations flags:(int)flags
{
    FMDatabase *database = [FMDatabase databaseWithPath:self.databasePath];
    
    if (![database openWithFlags:flags]) {
        NSLog(@"Could not open database: %@", database.lastErrorMessage);
        return NO;
    }
    
    [self createMigrationTableWithDatabase:database];
    
    int version = [self currentVersionWithDatabase:database];
    
    if (migrations.count > version) {
        
        NSLog(@"Starting schema migration (version %d to %lu)...", version, (unsigned long) migrations.count);
        
        BOOL fail = NO;
        
        for (int i = version; i < migrations.count && !fail; i++) {
            if (![database beginTransaction]) {
                NSLog(@"Could not begin transaction: %@", database.lastErrorMessage);
                return NO;
            }
            
            int currentVersion = i + 1;
            FMMigration *migration = [migrations objectAtIndex:i];
            
            NSMutableString *migrationLog = [NSMutableString stringWithFormat:@"Schema migration version %d...", currentVersion];
            
            fail = ![migration upgradeWithDatabase:database];
            
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
        return [database executeUpdate:sql];
    }];
    
    return migration;
}

- (FMMigration *)createTable:(NSString *)tableName primaryKey:(NSString *)primaryKey
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        NSString *sql = [self sqlCreateTable:tableName primaryKey:primaryKey];
        return [database executeUpdate:sql];
        
    } down:^(FMDatabase *database) {
        NSString *sql = [self sqlDropTable:tableName];
        return [database executeUpdate:sql];
    }];
    
    return migration;
}

- (NSString *)sqlCreateTable:(NSString *)tableName primaryKey:(NSString *)primaryKey
{
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ INTEGER PRIMARY KEY AUTOINCREMENT)", tableName, primaryKey];
}

- (FMMigration *)createTable:(NSString *)tableName columns:(NSArray *)columns
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        NSString *sql = [self sqlCreateTable:tableName columns:columns];
        return [database executeUpdate:sql];
        
    } down:^(FMDatabase *database) {
        NSString *sql = [self sqlDropTable:tableName];
        return [database executeUpdate:sql];
    }];
    
    return migration;
}

- (NSString *)sqlCreateTable:(NSString *)tableName columns:(NSArray *)columns
{
    NSMutableString *sql = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (", tableName];
    [sql appendString:[columns componentsJoinedByString:@","]];
    [sql appendString:@")"];
    
    return [NSString stringWithString:sql];
}

- (FMMigration *)renameTable:(NSString *)tableName to:(NSString *)newTableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        NSString *sql = [self sqlRenameTable:tableName to:newTableName];
        return [database executeUpdate:sql];
        
    } down:^(FMDatabase *database) {
        NSString *sql = [self sqlRenameTable:newTableName to:tableName];
        return [database executeUpdate:sql];
    }];
    
    return migration;
}

- (NSString *)sqlRenameTable:(NSString *)tableName to:(NSString *)newTableName
{
    return [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", tableName, newTableName];
}

- (FMMigration *)dropTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        NSString *sql = [self sqlDropTable:tableName];
        return [database executeUpdate:sql];
        
    }];
    
    return migration;
}

- (NSString *)sqlDropTable:(NSString *)tableName
{
    return [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tableName];
}

- (FMMigration *)addColumn:(NSString *)column type:(NSString *)type forTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        NSString *sql = [self sqlAddColumn:column type:(NSString *)type forTable:tableName];
        return [database executeUpdate:sql];
        
    } down:^(FMDatabase *database) {
        NSArray *sqls = [self sqlDropColumn:column forTable:tableName database:database];
        
        for (NSString *sql in sqls) {
            if (![database executeUpdate:sql]) {
                return NO;
            }
        }
        
        return YES;
    }];
    
    return migration;
}

- (NSString *)sqlAddColumn:(NSString *)column type:(NSString *)type forTable:(NSString *)tableName
{
    return [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@", tableName, [NSString stringWithFormat:@"%@ %@", column, type]];
}

- (FMMigration *)renameColumn:(NSString *)column to:(NSString *)newColumn forTable:(NSString *)tableName
{
    FMMigration *migration = [[FMMigration alloc] initWithUp:^(FMDatabase *database) {
        NSArray *sqls = [self sqlsRenameColumn:column to:newColumn forTable:tableName database:database];
        
        for (NSString *sql in sqls) {
            if (![database executeUpdate:sql]) {
                return NO;
            }
        }
        
        return YES;
        
    } down:^(FMDatabase *database) {
        NSArray *sqls = [self sqlsRenameColumn:newColumn to:column forTable:tableName database:database];
        
        for (NSString *sql in sqls) {
            if (![database executeUpdate:sql]) {
                return NO;
            }
        }
        
        return YES;
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
        NSArray *sqls = [self sqlDropColumn:column forTable:tableName database:database];
        
        for (NSString *sql in sqls) {
            if (![database executeUpdate:sql]) {
                return NO;
            }
        }
        
        return YES;
        
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
