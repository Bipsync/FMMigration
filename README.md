FMMigration
===========

FMMigration is a schema migration for SQLite FMDB library written in Objective-C

## Installation

FMMigration depends of FMDB library to work. So first, configure the FMDB library into your Xcode project.
After that, copy the files in [FMMigration folder](http://github.com/felipowsky/FMMigration/tree/master/FMMigration/FMMigration) into your project.

It's done!

## Usage

To do a schema migration you need to instantiate a `FMMigrationManager` and setup a list of migrations.
You should do this at the beginning of you application to ensure that your database will be updated to perform queries/statments properly.

Each element in the list of migrations needs to be a instance of `FMMigration`.

To execute the schema migration process you just call `migrateWithMigrations` method from `FMMigrationManager`.

Here is an example:

	NSString *databasePath = @"database.sqlite";
	FMMigrationManager *migration = [[FMMigrationManager alloc] initWithDatabasePath:databasePath];
	NSArray *migrations = @[
							[CreateTableAnimalMigration new],
							];
    [migration migrateWithMigrations:migrations];

Notice that CreateTableAnimalMigration is a subclass of 'FMMigration' class.

## License

The license for FMMigration is contained in the [license file](http://github.com/felipowsky/FMMigration/blob/master/LICENSE)