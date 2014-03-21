FMMigration
===========

FMMigration is a schema migration for SQLite FMDB library written in Objective-C

## Installation

FMMigration depends of FMDB library to work. So first, configure the FMDB library into your Xcode project.

After that, copy the files in [FMMigration folder](http://github.com/felipowsky/FMMigration/tree/master/FMMigration/FMMigration) into your project.

You're ready to go!

## Usage

To do a schema migration you need to instantiate a `FMMigrationManager` and setup a list of migrations.
You should do this at the beginning of your application to ensure that the database will be updated to perform queries/statments properly.

Each element in the list of migrations needs to be an instance of `FMMigration`.

To execute the schema migration process you just call `migrateWithMigrations` method from `FMMigrationManager`.

Here is an example:

	NSString *databasePath = @"database.sqlite";
	FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
	NSArray *migrations = @[
							[CreateTableAnimalMigration new],
							];
    [migration migrateWithMigrations:migrations];

Notice that CreateTableAnimalMigration is a subclass of `FMMigration`.

To facilitate some common database operations, `FMMigrationManager` already has some pre-defined operations to create, drop or rename tables or columns.

Here are some examples:

	NSString *databasePath = @"database.sqlite";
    FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
    NSArray *migrations = @[
    						[migration createTable:@"person" primaryKey:@"id"],
                            [migration addColumn:@"name" type:@"text" forTable:@"person"],
                            [migration addColumn:@"age" type:@"integer" forTable:@"person"],
                            [migration addColumn:@"favorite" type:@"text" forTable:@"person"],
                            [migration renameColumn:@"favorite" to:@"favorite_color" forTable:@"person"],
                            [migration dropColumn:@"favorite_color" forTable:@"person"],
                            [migration createTable:@"extra_table" primaryKey:@"id"],
                            [migration dropTable:@"extra_table"],
                            ];
    [migration migrateWithMigrations:migrations];

Maybe you want to perfom some custom query. For this case you can use `executeSQL` from `FMMigrationManager`.

Like this:

	NSString *databasePath = @"database.sqlite";
    FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
    NSArray *migrations = @[
    						[migration createTable:@"person" primaryKey:@"id"],
                            [migration addColumn:@"name" type:@"text" forTable:@"person"],
    						[migration executeSQL:@"INSERT INTO person (name) VALUES ('John')"],
    						];
    [migration migrateWithMigrations:migrations];

If you want to perform custom queries without the need to create a new subclass of `FMMigration` you can use `migrationWithUp` or `migrationWithUp:down` from `FMMigration`.
In this case, don't forget that you need to return a 'NSArray' as a result for up and down operations.

Here is an example:

	NSString *databasePath = @"database.sqlite";
    FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
    NSArray *migrations = @[
    						[migration createTable:@"person" primaryKey:@"id"],
                            [migration createTable:@"food" primaryKey:@"id"],
                            [migration addColumn:@"name" type:@"text" forTable:@"person"],
                            [migration addColumn:@"name" type:@"text" forTable:@"food"],
                            [FMMigration migrationWithUp:^NSArray *(FMDatabase *database) {
                                NSMutableArray *sqls = [[NSMutableArray alloc] init];
                                
                                for (int i = 0; i < 10; i++) {
                                    [sqls addObject:[NSString stringWithFormat:@"INSERT INTO person (name) VALUES ('Person %d')", i + 1]];
                                    [sqls addObject:[NSString stringWithFormat:@"INSERT INTO food (name) VALUES ('Food %d')", i + 1]];
                                }
                                
                                return [NSArray arrayWithArray:sqls];
                            }],
                            ];
    [migration migrateWithMigrations:migrations];

Finally, if you really want to organize your schema migrations in classes, you need to create a subclass of `FMMigration` and override `upgradeWithDatabase` and `downgradeWithDatabase` for up and down operations, respectively.

Here is CreateTableAnimalMigration's implementation example:

	@implementation CreateTableAnimalMigration

	- (NSArray *)upgradeWithDatabase:(FMDatabase *)database
	{
    	NSMutableArray *sqls = [[NSMutableArray alloc] init];
    
    	[sqls addObject:@"CREATE TABLE IF NOT EXISTS animal (id INTEGER PRIMARY KEY AUTOINCREMENT, name text)"];
    
    	for (int i = 0; i < 10; i++) {
        	[sqls addObject:[NSString stringWithFormat:@"INSERT INTO animal (name) VALUES ('Animal %d')", i + 1]];
    	}
    
    	return sqls;
	}

	- (NSArray *)downgradeWithDatabase:(FMDatabase *)database
	{
    	return @[@"DROP TABLE IF EXISTS animal"];
	}

	@end

## License

The license for FMMigration is contained in the [license file](http://github.com/felipowsky/FMMigration/blob/master/LICENSE)