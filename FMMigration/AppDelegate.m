#import "AppDelegate.h"
#import "FMMigration.h"
#import "FMDatabaseAdditions.h"
#import "CreateTableAnimalMigration.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSString *databasePath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"database.sqlite"];
    
    FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
    
    NSArray *migrations = @[
                            [migration createTable:@"person" primaryKey:@"id"],
                            [migration createTable:@"food" primaryKey:@"id"],
                            [migration addColumn:@"name" type:@"text" forTable:@"food"],
                            [migration addColumn:@"name" type:@"text" forTable:@"person"],
                            [migration addColumn:@"age" type:@"integer" forTable:@"person"],
                            [migration addColumn:@"favorite" type:@"text" forTable:@"person"],
                            [FMMigration migrationWithUp:^BOOL (FMDatabase *database) {
                                for (int i = 0; i < 10; i++) {
                                    if (![database executeUpdate:@"INSERT INTO person (name) VALUES (?)", [NSString stringWithFormat:@"Person %d", i + 1]]) {
                                        return NO;
                                    }
                                    
                                    if (![database executeUpdate:@"INSERT INTO food (name) VALUES (?)", [NSString stringWithFormat:@"Food %d", i + 1]]) {
                                        return NO;
                                    }
                                }
                                
                                return YES;
                            }],
                            [migration renameColumn:@"favorite" to:@"favorite_color" forTable:@"person"],
                            [migration dropColumn:@"favorite_color" forTable:@"person"],
                            [migration executeSQL:@"INSERT INTO person (name) VALUES ('Extra Person')"],
                            [migration createTable:@"extra_table" primaryKey:@"id"],
                            [migration dropTable:@"extra_table"],
                            [CreateTableAnimalMigration new],
                            ];
    
    [migration migrateWithMigrations:migrations];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
