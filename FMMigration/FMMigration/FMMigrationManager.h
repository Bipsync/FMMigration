#import <Foundation/Foundation.h>

@class FMMigration;

@interface FMMigrationManager : NSObject

- (id)initWithDatabasePath:(NSString *)databasePath;
- (id)initWithDatabasePath:(NSString *)databasePath migrationTable:(NSString *)migrationTableName;
- (BOOL)migrateWithMigrations:(NSArray *)migrations;
- (BOOL)migrateWithMigrations:(NSArray *)migrations flags:(int)flags;
- (FMMigration *)executeSQL:(NSString *)sql;
- (FMMigration *)createTable:(NSString *)tableName primaryKey:(NSString *)primaryKey;
- (FMMigration *)createTable:(NSString *)tableName columns:(NSArray *)columns;
- (FMMigration *)renameTable:(NSString *)tableName to:(NSString *)newTableName;
- (FMMigration *)dropTable:(NSString *)tableName;
- (FMMigration *)addColumn:(NSString *)column type:(NSString *)type forTable:(NSString *)tableName;
- (FMMigration *)renameColumn:(NSString *)column to:(NSString *)newColumn forTable:(NSString *)tableName;
- (FMMigration *)dropColumn:(NSString *)column forTable:(NSString *)tableName;

@end
