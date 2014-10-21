//
//  MYCUpdateAccountOperation.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCUpdateAccountOperation.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCTransaction.h"
#import "MYCUnspentOutput.h"
#import "MYCBackend.h"
#import "MYCDatabase.h"

/*
 ANALYSIS OF THE MYCELIUM WALLET ON ANDROID:

 1. From time to time, app does discovery of new transactions:
 Bip44Account.doDiscovery
    Wapi.queryTransactionInventory - loads transactions mentioning the addresses (must use limit: parameter to get > 0 items)
        AbstractAccount.handleNewExternalTransaction
            AbstractAccount.fetchStoreAndValidateParentOutputs
                tries to find existing outputs
                if fails, tries to find stored transactions and get outputs from there
                if fails, runs Wapi.getTransactions and saves outputs on disk

 2. Afterwards, it updates unspent outputs:

 Bip44Account.updateUnspentOutputs
    - finds all external and change addresses within the current scan range
        AbstractAccount.synchronizeUnspentOutputs with these addresses
            Wapi.queryUnspentOutputs
                Deletes local unspents that do not exist on the server.
                If unspent is not saved locally or was unconfirmed (different block height),
                    calls Wapi.getTransactions (with subsequent handleNewExternalTransaction)
                    And saves all unspent outputs.

 3. AbstractAccount.monitorYoungTransactions (up to 5 confirmations)
    It does Wapi.checkTransactions and simply updates transactions that were updated (reorged or confirmed).

 4. Bip44Account.updateLocalBalance - recomputes local balance for the account.

 */


@interface MYCUpdateAccountOperation ()
@property(nonatomic, readwrite) MYCWalletAccount* account;

// Latest used indices for invoices and change respectively.
@property(nonatomic) NSInteger latestExternalIndex;
@property(nonatomic) NSInteger latestInternalIndex;
@end

@implementation MYCUpdateAccountOperation

// Creates new operation object with a given account.
- (id) initWithAccount:(MYCWalletAccount*)account wallet:(MYCWallet*)wallet
{
    NSParameterAssert(account);
    if (!account) return nil;

    NSParameterAssert(wallet);
    if (!wallet) return nil;

    if (self = [super init])
    {
        _account = account;
        _wallet = wallet;
        _externalAddressesLookAhead = 20;
        _internalAddressesLookAhead = 2;
        _discoveryEnabled = YES;
    }
    return self;
}

// Begins account update.
- (void) update:(void(^)(BOOL success, NSError* error))completion
{
    [self.wallet inDatabase:^(FMDatabase *db) {
        // Make sure we use the latest data.
        [self.account reloadFromDatabase:db];
    }];

    [self discoverAddresses:^(BOOL success, NSError *error) {

        if (!success)
        {
            [self log:[NSString stringWithFormat:@"Failed address discovery, returning error %@", error]];
            if (completion) completion(NO, error);
            return;
        }

        // Now we know all used addresses and therefore can update unspent and spent outputs.

    }];
}



- (void) discoverAddresses:(void(^)(BOOL success, NSError* error))completion
{
    // Exit early if no discovery is required.
    if (!_discoveryEnabled)
    {
        [self log:@"Not discovering new used addresses because self.discoveryEnabled == NO."];
        if (completion) completion(YES, nil);
        return;
    }

    // Prepare indexes to scan.
    // These are "last used one" while account.*keyIndex is the first unused one.
    // We do not substract one because these keys are already visible and could have been used by someone before we synced.
    // So strictly speaking they can't be considered 100% unused.
    self.latestExternalIndex = self.account.externalKeyIndex;
    self.latestInternalIndex = self.account.internalKeyIndex;

    [self log:[NSString stringWithFormat:@"Starting discovery of new addresses after external index %d and internal index %d", (int)self.latestExternalIndex, (int)self.latestInternalIndex]];

    // Recursively discover more used addresses if we find anything.
    // The callback will not be called
    [self doDiscoverAddresses:^(BOOL success, BOOL foundAny, NSError *error) {

        // Failed - propagate error to the caller.
        if (!success)
        {
            if (completion) completion(NO, error);
            return;
        }

        // Discovered all addresses. Finish.
        if (!foundAny)
        {
            [self log:@"Finished discovery of used addresses."];
            if (completion) completion(YES, nil);
            return;
        }

        // Has found some addresses, which means we should try again recursively.
        [self log:@"Recursively continuing discovery of used addresses."];
        [self discoverAddresses:completion];
    }];
}

- (void) doDiscoverAddresses:(void(^)(BOOL success, BOOL foundAny, NSError* error))completion
{
    NSMutableArray* addresses = [NSMutableArray array];

    BTCKeychain* externalKeychain = [self.account.keychain derivedKeychainAtIndex:0];
    BTCKeychain* internalKeychain = [self.account.keychain derivedKeychainAtIndex:1];
    for (int i = 0; i <= self.externalAddressesLookAhead; i++)
    {
        BTCKey* key = [externalKeychain keyAtIndex:(uint32_t)self.latestExternalIndex + i hardened:NO];
        if (key) [addresses addObject:key.address];
    }
    for (int i = 0; i <= self.internalAddressesLookAhead; i++)
    {
        BTCKey* key = [internalKeychain keyAtIndex:(uint32_t)self.latestInternalIndex + i hardened:NO];
        if (key) [addresses addObject:key.address];
    }

    // Load all known transactions for the given addresses.
    [self.wallet.backend loadTransactionsForAddresses:addresses limit:1000 completion:^(NSArray *transactions, NSInteger height, NSError *error) {

        if (!transactions)
        {
            if (completion) completion(NO, NO, error);
            return;
        }

        // Update blockchain height for usage throughout the app.
        [self log:[NSString stringWithFormat:@"Updating blockchain height: %d", (int)height]];
        self.wallet.blockchainHeight = height;

        [self saveTransactions:transactions completion:^(BOOL success, NSError *error) {

            if (!success)
            {
                 if (completion) completion(NO, NO, error);
                return;
            }

            // Fetch parent outputs.
            // Parent outputs are used to figure which inputs are ours when we compute balance.
            // Technically, we could assume all payments to be P2PKH and extract pubkey from the input without fetching parent outputs,
            // but for consistency and extensibility we check the destination via the output script.
            [self fetchRelevantParentOutputsFromTransactions:transactions completion:^(BOOL success, NSError *error) {
                if (!success)
                {
                    if (completion) completion(NO, NO, error);
                    return;
                }

                // Report that we found some transactions.
                if (completion) completion(YES, YES, nil);
            }];
        }]; // save txs.
    }]; // load txs for addresses
}


- (void) fetchRelevantParentOutputsFromTransactions:(NSArray*)txs completion:(void(^)(BOOL success, NSError* error))completion
{
    NSUInteger accountIndex = self.account.accountIndex;
    MYCWallet* wallet = self.wallet;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

        NSMutableArray* txidsToFetch = [NSMutableArray array];


        [self.wallet inDatabase:^(FMDatabase *db) {
            for (BTCTransaction* tx in txs)
            {
                if (!tx.isCoinbase)
                {
                    
                    //                TransactionOutputEx parentOutput = _backing.getParentTransactionOutput(in.outPoint);
                    //                if (parentOutput != null) {
                    //                    // We already have the parent output, no need to fetch the entire
                    //                    // parent transaction
                    //                    parentOutputs.put(parentOutput.outPoint, parentOutput);
                    //                    continue;
                    //                }
                    //                TransactionEx parentTransaction = _backing.getTransaction(in.outPoint.hash);
                    //                if (parentTransaction != null) {
                    //                    // We had the parent transaction in our own transactions, no need to
                    //                    // fetch it remotely
                    //                    parentTransactions.put(parentTransaction.txid, parentTransaction);
                    //                } else {
                    //                    // Need to fetch it
                    //                    toFetch.add(in.outPoint.hash);
                    //                }
                    
                    
                    [txidsToFetch addObjectsFromArray:[tx.inputs valueForKey:@"previousTransactionID"]];
                }
            }

        }];

    });

    completion(YES, nil);
}

- (void) saveTransactions:(NSArray*)txs completion:(void(^)(BOOL success, NSError* error))completion
{
    NSUInteger accountIndex = self.account.accountIndex;
    MYCWallet* wallet = self.wallet;

    // We'll use these to advance indices
    NSInteger externalStartIndex = self.latestExternalIndex;
    NSInteger internalStartIndex = self.latestInternalIndex;

    NSInteger externalEndIndex = externalStartIndex + self.externalAddressesLookAhead;
    NSInteger internalEndIndex = internalStartIndex + self.externalAddressesLookAhead;

    BTCKeychain* externalKeychain = [self.account.keychain derivedKeychainAtIndex:0];
    BTCKeychain* internalKeychain = [self.account.keychain derivedKeychainAtIndex:1];

    // We may have a lot of transactions, so lets do all DB work on a background thread.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

        // Store transactions on disk.
        __block NSError* error = nil;
        [wallet inDatabase:^(FMDatabase *db) {

            // 1. Save or update transactions on disk.
            // 2. Advance used address indexes for this account.

            // Before going through transactions, prepare NSData blobs for each output script.
            NSInteger externalCurrentIndex = -1;
            NSInteger internalCurrentIndex = -1;

            NSMutableArray* externalScriptBlobs = [NSMutableArray array];
            NSMutableArray* internalScriptBlobs = [NSMutableArray array];
            for (NSInteger i = externalStartIndex; i <= externalEndIndex; i++)
            {
                BTCScript* script = [[BTCScript alloc] initWithAddress:[externalKeychain keyAtIndex:(uint32_t)i].address];
                [externalScriptBlobs addObject:script.data];
            }
            for (NSInteger i = internalStartIndex; i <= internalEndIndex; i++)
            {
                BTCScript* script = [[BTCScript alloc] initWithAddress:[internalKeychain keyAtIndex:(uint32_t)i].address];
                [internalScriptBlobs addObject:script.data];
            }

            for (BTCTransaction* tx in txs)
            {
                MYCTransaction* mtx = [[MYCTransaction alloc] init];

                mtx.transactionHash = tx.transactionHash;
                mtx.data            = tx.data;
                mtx.blockHeight     = tx.blockHeight;
                mtx.date            = tx.blockDate;
                mtx.accountIndex    = accountIndex;

                NSError* dberror = nil;
                if (![mtx saveInDatabase:db error:&dberror])
                {
                    error = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error"}];
                    MYCError(@"MYCWallet: failed to save transaction %@ for account %d in database: %@", tx.transactionID, (int)accountIndex, dberror);
                    return;
                }

                for (BTCTransactionOutput* txout in tx.outputs)
                {
                    NSData* blob = txout.script.data;
                    NSUInteger i = [externalScriptBlobs indexOfObject:blob];
                    if (i != NSNotFound)
                    {
                        externalCurrentIndex = MAX(externalCurrentIndex, externalStartIndex + i);
                    }
                    else
                    {
                        i = [internalScriptBlobs indexOfObject:blob];
                        if (i != NSNotFound)
                        {
                            internalCurrentIndex = MAX(internalCurrentIndex, internalStartIndex + i);
                        }
                    }
                } // for each txout
            } // for each tx

            // We normally do not fail to write txs into DB, so it's okay to advance indexes once we iterated over all transactions.
            if (externalCurrentIndex > 0 || internalCurrentIndex > 0)
            {
                // Bump indexes by 1 for the current account and save it.
                self.account.externalKeyIndex = (uint32_t)MAX(self.account.externalKeyIndex, externalCurrentIndex + 1);
                self.account.internalKeyIndex = (uint32_t)MAX(self.account.internalKeyIndex, internalCurrentIndex + 1);

                [self log:[NSString stringWithFormat:@"Bumped key indexes for account: external=%d internal=%d", (int)self.account.externalKeyIndex, (int)self.account.internalKeyIndex]];

                NSError* dberror = nil;
                if (![self.account saveInDatabase:db error:&dberror])
                {
                    error = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error"}];
                    MYCError(@"MYCWallet: failed to save account %d after bumping key indexes in database: %@", (int)accountIndex, dberror);
                    return;
                }
            }
        }];

        // Continue on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(!error, error);
        });
    });
}

- (void) log:(NSString*)message
{
    MYCLog(@"MYCUpdateAccountOperation[%d]: %@", (int)self.account.accountIndex, message);
}

@end
