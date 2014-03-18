//
//  CreateTableAnimalMigration.m
//  FMMigration
//
//  Created by Morphy on 18/03/14.
//  Copyright (c) 2014 Felipe Augusto. All rights reserved.
//

#import "CreateTableAnimalMigration.h"

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
