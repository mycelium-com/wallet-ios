//
//  MYCDatabaseMigrations.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MYCDatabase.h"

@interface MYCDatabaseMigrations : NSObject

+ (void) registerMigrations:(MYCDatabase*)mycdatabase;

@end
