#import <Foundation/Foundation.h>

#import "FMMigrationManager.h"
#import "FMDB/FMDatabase.h"

@interface FMMigration : NSObject

@property (nonatomic, strong) FMDatabase *database;

+ (instancetype)migrationWithUp:(BOOL (^) (FMDatabase *))upBlock;
+ (instancetype)migrationWithUp:(BOOL (^) (FMDatabase *))upBlock down:(BOOL (^) (FMDatabase *))downBlock;
- (id)initWithUp:(BOOL (^) (FMDatabase *))upBlock;
- (id)initWithUp:(BOOL (^) (FMDatabase *))upBlock down:(BOOL (^) (FMDatabase *))downBlock;

- (BOOL)up;
- (BOOL)down;
- (BOOL)upgradeWithDatabase:(FMDatabase *)database;
- (BOOL)downgradeWithDatabase:(FMDatabase *)database;

@end
