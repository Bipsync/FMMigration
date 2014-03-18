#import "FMMigration.h"

typedef NSArray * (^UpBlock)(FMDatabase *);
typedef NSArray * (^DownBlock)(FMDatabase *);

@interface FMMigration ()

@property (nonatomic, copy) UpBlock upBlock;
@property (nonatomic, copy) DownBlock downBlock;

@end

@implementation FMMigration

+ (instancetype)migrationWithUp:(NSArray *(^) (FMDatabase *))upBlock
{
    return [[FMMigration alloc] initWithUp:upBlock];
}

+ (instancetype)migrationWithUp:(NSArray *(^) (FMDatabase *))upBlock down:(NSArray *(^) (FMDatabase *))downBlock
{
    return [[FMMigration alloc] initWithUp:upBlock down:downBlock];
}

- (id)init
{
    self = [super init];
    
    if (self) {
        self.upBlock = ^(FMDatabase *database) {
            return @[];
        };
        self.downBlock = ^(FMDatabase *database) {
            return @[];
        };
    }
    
    return self;
}

- (id)initWithUp:(NSArray * (^)(FMDatabase *))upBlock
{
    self = [super init];
    
    if (self) {
        self.upBlock = upBlock;
        self.downBlock = ^(FMDatabase *database) {
            return @[];
        };
    }
    
    return self;
}

- (id)initWithUp:(NSArray * (^)(FMDatabase *))upBlock down:(NSArray * (^)(FMDatabase *))downBlock
{
    self = [super init];
    
    if (self) {
        self.upBlock = upBlock;
        self.downBlock = downBlock;
    }
    
    return self;
}

- (NSArray *)up
{
    return self.upBlock(self.database);
}

- (NSArray *)down
{
    return self.downBlock(self.database);
}

- (NSArray *)upgradeWithDatabase:(FMDatabase *)database
{
    self.database = database;
    
    return [self up];
}

- (NSArray *)downgradeWithDatabase:(FMDatabase *)database
{
    self.database = database;
    
    return [self down];
}

@end
