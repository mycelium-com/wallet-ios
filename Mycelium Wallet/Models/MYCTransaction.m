//
//  MYCTransaction.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTransaction.h"
#import "MYCTransactionDetails.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCParentOutput.h"

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
    return BTCIDFromHash(self.transactionHash);
}

- (void) setTransactionID:(NSString *)transactionID
{
    self.transactionHash = BTCHashFromID(transactionID);
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
    return BTCHexFromData(self.data);
}



#pragma mark - Transaction Details


- (MYCWalletAccount*) getAccount:(FMDatabase*)db
{
    if (!_account)
    {
        _account = [MYCWalletAccount loadAccountAtIndex:_accountIndex fromDatabase:db];
    }
    return _account;
}

// Loads basic details about transaction from database (label, amountTransferred).
- (BOOL) loadDetailsFromDatabase:(FMDatabase*)db
{
    BTCTransaction* tx = self.transaction;
    MYCWalletAccount* account = [self getAccount:db];

    if (!self.transactionDetails) {
        self.transactionDetails = [MYCTransactionDetails loadWithPrimaryKey:@[self.transactionHash] fromDatabase:db];
    }

    self.amountTransferred = 0;
    self.inputsAmount = 0;
    self.outputsAmount = 0;
    self.fee = 0;

    BTCScript* ourDestinationScript = nil;
    BTCScript* destinationScript = nil;
    BTCScript* changeScript = nil;

    // 1. For each of our outputs, increment amount.
    // 2. For each of our inputs, decrement amount.
    for (BTCTransactionOutput* txout in tx.outputs)
    {
        self.outputsAmount += txout.value;
        NSInteger changeIndex = 0;
        if ([account matchesScriptData:txout.script.data change:&changeIndex keyIndex:NULL])
        {
            self.amountTransferred += txout.value;
            if (changeIndex == 1)
            {
                changeScript = txout.script;
            }
            else
            {
                ourDestinationScript = txout.script;
            }
        }
        else // not our address.
        {
            destinationScript = txout.script;
        }
    }

    self.transactionOutputs = tx.outputs;

    if (!tx.isCoinbase)
    {
        for (BTCTransactionInput* txin in tx.inputs)
        {
            MYCParentOutput* mout = [MYCParentOutput loadOutputForAccount:account.accountIndex hash:txin.previousHash index:txin.previousIndex database:db];
            if (mout) {
                self.inputsAmount += mout.value;
                if ([mout isMyOutput])
                {
                    self.amountTransferred  -= mout.value;
                }
                txin.userInfo = @{@"value": @(mout.value),
                                  @"address": [[MYCWallet currentWallet] addressForAddress:mout.script.standardAddress],
                                  @"script": mout.script};
            }
        }
    }

    self.transactionInputs = tx.inputs;
    self.fee = self.inputsAmount - self.outputsAmount;

    // Normally we'll have one of these transactions:
    // 1. We are paying: one output is change, another is destination (which can be our external address or change address).
    // 2. We are receiving: one output is ours, others could be anything.

    BTCScript* script = nil;
    if (self.amountTransferred  > 0)
    {
        // Getting money, prefer our address.
        script = ourDestinationScript ?: changeScript ?: destinationScript;
    }
    else
    {
        script = destinationScript ?: ourDestinationScript ?: changeScript;
    }

    // Convert to Testnet/Mainnet as needed.
    BTCAddress* address = [[MYCWallet currentWallet] addressForAddress:script.standardAddress];

    self.label = address.string;
    self.label = self.label ?: @"—";
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
