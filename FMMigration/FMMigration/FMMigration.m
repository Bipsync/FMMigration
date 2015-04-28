#import "FMMigration.h"

typedef BOOL (^UpBlock)(FMDatabase *);
typedef BOOL (^DownBlock)(FMDatabase *);

@interface FMMigration ()

@property (nonatomic, copy) UpBlock upBlock;
@property (nonatomic, copy) DownBlock downBlock;

@end

@implementation FMMigration

+ (instancetype)migrationWithUp:(BOOL (^) (FMDatabase *))upBlock
{
    return [[FMMigration alloc] initWithUp:upBlock];
}

+ (instancetype)migrationWithUp:(BOOL (^) (FMDatabase *))upBlock down:(BOOL (^) (FMDatabase *))downBlock
{
    return [[FMMigration alloc] initWithUp:upBlock down:downBlock];
}

- (id)init
{
    self = [super init];
    
    if (self) {
        self.upBlock = ^(FMDatabase *database) {
            return YES;
        };
        self.downBlock = ^(FMDatabase *database) {
            return YES;
        };
    }
    
    return self;
}

- (id)initWithUp:(BOOL (^)(FMDatabase *))upBlock
{
    self = [super init];
    
    if (self) {
        self.upBlock = upBlock;
        self.downBlock = ^(FMDatabase *database) {
            return YES;
        };
    }
    
    return self;
}

- (id)initWithUp:(BOOL (^)(FMDatabase *))upBlock down:(BOOL (^)(FMDatabase *))downBlock
{
    self = [super init];
    
    if (self) {
        self.upBlock = upBlock;
        self.downBlock = downBlock;
    }
    
    return self;
}

- (BOOL)up
{
    return self.upBlock(self.database);
}

- (BOOL)down
{
    return self.downBlock(self.database);
}

- (BOOL)upgradeWithDatabase:(FMDatabase *)database
{
    self.database = database;
    
    return [self up];
}

- (BOOL)downgradeWithDatabase:(FMDatabase *)database
{
    self.database = database;
    
    return [self down];
}

@end
