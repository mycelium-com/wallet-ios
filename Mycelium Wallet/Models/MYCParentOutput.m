//
//  MYCParentOutput.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCParentOutput.h"

@implementation MYCParentOutput

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


#pragma mark - MYCDatabaseRecord


+ (NSString *)tableName
{
    return @"MYCParentOutputs";
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
