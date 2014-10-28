//
//  MYCBaseTxOutput.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBaseTxOutput.h"
#import "MYCWallet.h"


@interface MYCBaseTxOutput ()
@property(nonatomic) NSString* outpointTxID; // MYCDebugHexDatabaseFields
@property(nonatomic) NSString* addressBase58; // MYCDebugHexDatabaseFields
@end

@implementation MYCBaseTxOutput

- (BTCScript*) script
{
    return [[BTCScript alloc] initWithData:self.scriptData];
}

- (void) setScript:(BTCScript *)script
{
    self.scriptData = script.data;
}

- (BTCTransactionOutput*) transactionOutput
{
    BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] initWithValue:self.value script:self.script];
    txout.blockHeight = self.blockHeight;
    txout.index = (uint32_t)self.outpointIndex;
    txout.transactionHash = self.outpointHash;
    return txout;
}

- (void) setTransactionOutput:(BTCTransactionOutput *)transactionOutput
{
    self.value = transactionOutput.value;
    self.script = transactionOutput.script;
    self.blockHeight = transactionOutput.blockHeight;
    self.outpointIndex = transactionOutput.index;
    self.outpointHash = transactionOutput.transactionHash;
}

- (BTCOutpoint*) outpoint
{
    return [[BTCOutpoint alloc] initWithHash:self.outpointHash index:(uint32_t)self.outpointIndex];
}

- (void) setOutpoint:(BTCOutpoint *)outpoint
{
    self.outpointHash = outpoint.txHash;
    self.outpointIndex = outpoint.index;
}

- (NSString*) outpointTxID
{
    return self.outpoint.txID;
}

- (NSString*) addressBase58
{
    return [[[MYCWallet currentWallet] addressForAddress:self.script.standardAddress] base58String];
}

- (BOOL) isMyOutput
{
    return self.accountIndex >= 0 && self.change >= 0 && self.keyIndex >= 0;
}

#pragma mark - Database Access


+ (instancetype) loadOutputForAccount:(NSInteger)accountIndex hash:(NSData*)prevHash index:(uint32_t)prevIndex database:(FMDatabase*)db
{
    return [[self loadWithCondition:@"accountIndex = ? AND outpointHash = ? AND outpointIndex = ?"
                             params:@[@(accountIndex), prevHash ?: @"n/a", @(prevIndex) ]
                       fromDatabase:db] firstObject];
}

+ (NSArray*) loadOutputsForAccount:(NSInteger)accountIndex database:(FMDatabase*)db
{
    return [self loadWithCondition:@"accountIndex = ? ORDER BY blockHeight ASC" params:@[@(accountIndex)] fromDatabase:db];
}


#pragma mark - MYCDatabaseRecord


+ (id) primaryKeyName
{
    return @[MYCDatabaseColumn(outpointHash),
             MYCDatabaseColumn(outpointIndex),
             MYCDatabaseColumn(accountIndex)];
}

+ (NSString *)tableName
{
    return @"OVERRIDE IN SUBCLASSES";
}

+ (NSArray *)columnNames
{
    return @[MYCDatabaseColumn(outpointHash),
#if MYCDebugHexDatabaseFields
             MYCDatabaseColumn(outpointTxID),
#endif
             MYCDatabaseColumn(outpointIndex),
             MYCDatabaseColumn(blockHeight),
             MYCDatabaseColumn(scriptData),
#if MYCDebugHexDatabaseFields
             MYCDatabaseColumn(addressBase58),
#endif
             MYCDatabaseColumn(value),
             MYCDatabaseColumn(coinbase),
             MYCDatabaseColumn(accountIndex),
             MYCDatabaseColumn(change),
             MYCDatabaseColumn(keyIndex),
             ];
}

@end
