//
//  MYCBaseTxOutput.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBaseTxOutput.h"

@implementation MYCBaseTxOutput

- (BTCScript*) script
{
    return [[BTCScript alloc] initWithData:self.scriptData];
}

- (BTCTransactionOutput*) transactionOutput
{
    BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] initWithValue:self.value script:self.script];
    txout.blockHeight = self.blockHeight;
    txout.index = (uint32_t)self.outpointIndex;
    txout.transactionHash = self.outpointHash;
    return txout;
}


#pragma mark - Database Access


+ (instancetype) loadOutputForAccount:(uint32_t)accountIndex hash:(NSData*)prevHash index:(uint32_t)prevIndex database:(FMDatabase*)db
{
    return [[self loadWithCondition:@"accountIndex = ? AND outpointHash = ? AND outpointIndex = ?"
                             params:@[@(accountIndex), prevHash ?: @"n/a", @(prevIndex) ]
                       fromDatabase:db] firstObject];
}


#pragma mark - MYCDatabaseRecord


+ (NSString *)tableName
{
    return @"OVERRIDE IN SUBCLASSES";
}

+ (NSArray *)columnNames
{
    return @[MYCDatabaseColumn(outpointHash),
             MYCDatabaseColumn(outpointIndex),
             MYCDatabaseColumn(blockHeight),
             MYCDatabaseColumn(scriptData),
             MYCDatabaseColumn(value),
             MYCDatabaseColumn(coinbase),
             MYCDatabaseColumn(accountIndex),
             MYCDatabaseColumn(change),
             MYCDatabaseColumn(keyIndex),
             ];
}

@end
