#import "CreateTableAnimalMigration.h"

@implementation CreateTableAnimalMigration

- (BOOL)upgradeWithDatabase:(FMDatabase *)database
{
    NSString *sql = @"CREATE TABLE IF NOT EXISTS animal (id INTEGER PRIMARY KEY AUTOINCREMENT, name text)";
    
    if (![database executeUpdate:sql]) {
        return NO;
    }
    
    for (int i = 0; i < 10; i++) {
        if (![database executeUpdate:@"INSERT INTO animal (name) VALUES (?)", [NSString stringWithFormat:@"Animal %d", i + 1]]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)downgradeWithDatabase:(FMDatabase *)database
{
    return [database executeUpdate:@"DROP TABLE IF EXISTS animal"];
}

@end
