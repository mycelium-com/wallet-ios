//
//  MYCTransaction.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTransaction.h"
#import "MYCWalletAccount.h"

static const NSInteger MYCTransactionBlockHeightUnconfirmed = 9999999;

@interface MYCTransaction ()
@property(nonatomic) NSTimeInterval timestamp;
@property(nonatomic) NSInteger blockHeightExt; // -1 converted to MYCTransactionBlockHeightUnconfirmed and vice versa
@property(nonatomic) NSString* dataHex; // MYCDebugHexDatabaseFields
@end

@implementation MYCTransaction

- (BTCTransaction*) transaction
{
    BTCTransaction* tx = [[BTCTransaction alloc] initWithData:self.data];
    tx.blockDate = self.date;
    tx.blockHeight = self.blockHeight;
    return tx;
}

- (void) setTransaction:(BTCTransaction *)transaction
{
    self.data = transaction.data;
    self.date = transaction.blockDate;
    self.blockHeight = transaction.blockHeight;
    self.transactionHash = transaction.transactionHash;
}

- (NSString*) transactionID
{
    return BTCTransactionIDFromHash(self.transactionHash);
}

- (void) setTransactionID:(NSString *)transactionID
{
    self.transactionHash = BTCTransactionHashFromID(transactionID);
}

- (NSDate *) date
{
    if (self.timestamp > 0.0) {
        return [NSDate dateWithTimeIntervalSince1970:self.timestamp];
    } else {
        return nil;
    }
}

- (void)setDate:(NSDate *)date
{
    if (date) {
        self.timestamp = [date timeIntervalSince1970];
    } else {
        self.timestamp = 0.0;
    }
}

- (NSInteger) blockHeight
{
    if (_blockHeightExt == MYCTransactionBlockHeightUnconfirmed) return -1;
    return _blockHeightExt;
}

- (void) setBlockHeight:(NSInteger)blockHeight
{
    _blockHeightExt = (blockHeight == -1) ? MYCTransactionBlockHeightUnconfirmed : blockHeight;
}

- (NSString*) dataHex
{
    return BTCHexStringFromData(self.data);
}



#pragma mark - Transaction Details


// Loads basic details about transaction from database (label, amountTransferred).
- (BOOL) loadBasicDetailsFromDatabase:(FMDatabase*)db
{
    
    return YES;
}

// Loads all details about transaction: inputs, outputs etc.
- (BOOL) loadFullDetailsFromDatabase:(FMDatabase*)db
{

    return YES;
}




#pragma mark - Database Access



// Finds a transaction in the database for a given hash. Returns nil if not found.
+ (instancetype) loadTransactionWithHash:(NSData*)txhash account:(MYCWalletAccount*)account database:(FMDatabase*)db
{
    MYCTransaction* tx = [[self loadWithCondition:@"accountIndex = ? AND transactionHash = ?"
                             params:@[@(account.accountIndex), txhash ?: @"n/a" ]
                       fromDatabase:db] firstObject];
    tx.account = account;
    return tx;
}


// Finds young transactions with a given height or newer (including unconfirmed ones).
+ (NSArray*) loadRecentTransactionsSinceHeight:(NSInteger)height account:(MYCWalletAccount*)account database:(FMDatabase*)db
{
    NSArray* txs = [self loadWithCondition:@"accountIndex = ? AND blockHeightExt > ?"
                             params:@[@(account.accountIndex), @(height) ]
                       fromDatabase:db];

    for (MYCTransaction* tx in txs) { tx.account = account; }
    return txs;
}

// Finds unconfirmed transactions (with height = -1)
+ (NSArray*) loadUnconfirmedTransactionsForAccount:(MYCWalletAccount*)account database:(FMDatabase*)db
{
    NSArray* txs = [self loadWithCondition:@"accountIndex = ? AND blockHeightExt == ?"
                            params:@[@(account.accountIndex), @(MYCTransactionBlockHeightUnconfirmed)]
                      fromDatabase:db];

    for (MYCTransaction* tx in txs) { tx.account = account; }
    return txs;
}

// Loads total number of transactions associated with this account
+ (NSUInteger) countTransactionsForAccount:(MYCWalletAccount*)account database:(FMDatabase*)db
{
    return [self countWithCondition:@"accountIndex = ?" params:@[ @(account.accountIndex) ] fromDatabase:db];
}

// Loads a transaction at index
+ (MYCTransaction*) loadTransactionAtIndex:(NSUInteger)txindex account:(MYCWalletAccount*)account database:(FMDatabase*)db
{
    MYCTransaction* tx = [[self loadWithCondition:@"accountIndex = ? ORDER BY blockHeightExt DESC, timestamp DESC LIMIT 1 OFFSET ?"
                             params:@[ @(account.accountIndex), @(txindex) ] fromDatabase:db] firstObject];

    tx.account = account;
    return tx;
}


#pragma mark - MYCDatabaseRecord



+ (id) primaryKeyName
{
    return @[MYCDatabaseColumn(transactionHash),
             MYCDatabaseColumn(accountIndex)];
}

+ (NSString *)tableName
{
    return @"MYCTransactions";
}

+ (NSArray *)columnNames
{
    return @[MYCDatabaseColumn(transactionHash),
#if MYCDebugHexDatabaseFields
             MYCDatabaseColumn(transactionID),
#endif
             MYCDatabaseColumn(data),
#if MYCDebugHexDatabaseFields
             MYCDatabaseColumn(dataHex),
#endif
             MYCDatabaseColumn(blockHeightExt),
             MYCDatabaseColumn(timestamp),
             MYCDatabaseColumn(accountIndex),
             ];
}

@end
