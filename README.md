# FMMigration

[![Build Status][travis-image]][travis-url]

FMMigration is a schema migration for SQLite FMDB library written in Objective-C

## Installation

FMMigration depends on FMDB library to work. So first, configure FMDB library into your Xcode project.

After that, copy the files in [FMMigration folder](http://github.com/felipowsky/FMMigration/tree/master/FMMigration/FMMigration) into your project.

You're ready to go!

## Usage

To do a schema migration you need to instantiate a `FMMigrationManager` and setup a list of migrations.
You should do this at the beginning of your application to ensure that the database will be updated to perform queries/statements properly.

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

Here is an example:

	NSString *databasePath = @"database.sqlite";
    FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
    NSArray *migrations = @[
    						[migration createTable:@"person" primaryKey:@"id"],
                            [migration createTable:@"food" primaryKey:@"id"],
                            [migration addColumn:@"name" type:@"text" forTable:@"person"],
                            [migration addColumn:@"name" type:@"text" forTable:@"food"],
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
                            ];
    [migration migrateWithMigrations:migrations];

Finally, if you want to organize your schema migrations in classes, you need to create a subclass of `FMMigration` and override `upgradeWithDatabase` and `downgradeWithDatabase` for up and down operations, respectively.

Here is an example:

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

## License

The license for FMMigration is contained in the [license file](http://github.com/felipowsky/FMMigration/blob/master/LICENSE)

[travis-url]:  https://travis-ci.org/felipowsky/FMMigration
[travis-image]: https://travis-ci.org/felipowsky/FMMigration.svg?style=flat
