#import <Foundation/Foundation.h>
#import "FMMigrationManager.h"
#import "FMDatabase.h"

@interface FMMigration : NSObject

@property (nonatomic, strong) FMDatabase *database;

+ (instancetype)migrationWithUp:(NSArray *(^) (FMDatabase *))upBlock;
+ (instancetype)migrationWithUp:(NSArray *(^) (FMDatabase *))upBlock down:(NSArray *(^) (FMDatabase *))downBlock;
- (id)initWithUp:(NSArray *(^) (FMDatabase *))upBlock;
- (id)initWithUp:(NSArray *(^) (FMDatabase *))upBlock down:(NSArray *(^) (FMDatabase *))downBlock;

- (NSArray *)up;
- (NSArray *)down;
- (NSArray *)upgradeWithDatabase:(FMDatabase *)database;
- (NSArray *)downgradeWithDatabase:(FMDatabase *)database;

@end
