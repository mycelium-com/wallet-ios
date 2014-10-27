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
#import "MYCParentOutput.h"
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
@property(nonatomic, readwrite) MYCBackend* backend;

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
        _backend = wallet.backend;
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
        [self updateUnspentOutputs:^(BOOL success, NSError* error){

            if (!success)
            {
                [self log:[NSString stringWithFormat:@"Failed updating unspent outputs, returning error %@", error]];
                if (completion) completion(NO, error);
                return;
            }

            [self updateYoungTransactions:^(BOOL success, NSError* error){

                if (!success)
                {
                    [self log:[NSString stringWithFormat:@"Failed updating young transactions, returning error %@", error]];
                    if (completion) completion(NO, error);
                    return;
                }

                [self updateLocalBalance:^(BOOL success, NSError* error){

                    if (!success)
                    {
                        [self log:[NSString stringWithFormat:@"Failed updating balance, returning error %@", error]];
                        if (completion) completion(NO, error);
                        return;
                    }

                    if (completion) completion(YES, nil);
                }];
            }];
        }];
    }];
}


- (void) updateUnspentOutputs:(void(^)(BOOL success, NSError* error))completion
{
    NSMutableArray* addresses = [NSMutableArray array];

    for (uint32_t i = 0; i <= self.account.externalKeyIndex; i++)
    {
        BTCKey* key = [self.account.externalKeychain keyAtIndex:i hardened:NO];
        if (key) [addresses addObject:[self.wallet addressForKey:key]];
    }
    // We control change addresses, so we look for unspents after the last spent change output.
    for (uint32_t i = self.account.internalKeyStartingIndex; i <= self.account.internalKeyIndex; i++)
    {
        BTCKey* key = [self.account.internalKeychain keyAtIndex:i hardened:NO];
        if (key) [addresses addObject:[self.wallet addressForKey:key]];
    }

    NSInteger accountIndex = self.account.accountIndex;

    [self.backend loadUnspentOutputsForAddresses:addresses completion:^(NSArray *outputs, NSInteger height, NSError *error) {

        if (!outputs)
        {
            if (completion) completion(NO, error);
            return;
        }

        // Update blockchain height for usage throughout the app.
        [self log:[NSString stringWithFormat:@"Updating blockchain height: %d", (int)height]];
        self.wallet.blockchainHeight = height;

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

            NSMutableSet* txidsToUpdate = [NSMutableSet set];

            __block NSError* dberror = nil;
            [self.wallet inDatabase:^(FMDatabase *db) {

                NSArray* localMYCUnspents = [MYCUnspentOutput loadAllFromDatabase:db];
                NSMutableDictionary* localMYCUnspentsByOutpoint = [NSMutableDictionary dictionary];
                for (MYCUnspentOutput* mout in localMYCUnspents)
                {
                    localMYCUnspentsByOutpoint[mout.outpoint] = mout;
                }

                NSMutableDictionary* remoteBTCUnspentsByOutpoint = [NSMutableDictionary dictionary];
                for (BTCTransactionOutput* txout in outputs)
                {
                    BTCOutpoint* outpoint = [[BTCOutpoint alloc] initWithHash:txout.transactionHash index:txout.index];
                    remoteBTCUnspentsByOutpoint[outpoint] = txout;
                }

                // 1. Remove all unspents from database that are not reported by the server

                for (MYCUnspentOutput* mout in localMYCUnspents)
                {
                    BTCOutpoint* outpoint = mout.outpoint;
                    if (!remoteBTCUnspentsByOutpoint[outpoint])
                    {
                        MYCLog(@"MYCUpdateAccountOperation: Removing unspent output from DB: %@", mout.transactionOutput);
                        if (![mout deleteFromDatabase:db error:&dberror])
                        {
                            dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error when deleting unspent output"}];
                            return;
                        }
                    }
                }

                // 2. Find new outputs and collect txids for all outputs that are new or updated.

                for (BTCTransactionOutput* txout in outputs)
                {
                    BTCOutpoint* outpoint = [[BTCOutpoint alloc] initWithHash:txout.transactionHash index:txout.index];

                    MYCUnspentOutput* mout = localMYCUnspentsByOutpoint[outpoint];

                    if (!mout || mout.blockHeight != txout.blockHeight)
                    {
                        if (!mout)
                        {
                            mout = [[MYCUnspentOutput alloc] init];
                            mout.transactionOutput = txout;
                            mout.accountIndex = accountIndex;

                            // Find which address is used on this output.
                            NSInteger change = 0;
                            NSInteger keyIndex = 0;
                            if ([self.account matchesScriptData:txout.script.data change:&change keyIndex:&keyIndex])
                            {
                                mout.change = change;
                                mout.keyIndex = keyIndex;
                            }
                            else
                            {
                                MYCError(@"MYCUpdateAccountOperation: could not find which key is using this output: %@:%d", BTCTransactionIDFromHash(txout.transactionHash), (int)txout.index);
                                mout = nil;
                            }
                        }

                        // If we have a valid unspent output, save it and update its transaction.
                        if (mout)
                        {
                            MYCLog(@"MYCUpdateAccountOperation: Adding new unspent output to DB: %@", txout);
                            // set latest version of unspent output.
                            mout.transactionOutput = txout;

                            [txidsToUpdate addObject:BTCTransactionIDFromHash(mout.outpointHash)];
                            //[moutputsToSave addObject:mout];

                            if (![mout insertInDatabase:db error:&dberror])
                            {
                                dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error when inserting new unspent outputs"}];
                                MYCError(@"MYCUpdateAccountOperation: failed to save unspent output %@ for account %d in database: %@", txout, (int)accountIndex, dberror);
                                return;
                            }
                            else
                            {
                                MYCLog(@"MYCUpdateAccountOperation: saved unspent output %@:%@", BTCTransactionIDFromHash(txout.transactionHash), @(txout.index));
                            }
                        }
                    }
                }
            }];

            dispatch_async(dispatch_get_main_queue(), ^{

                if (dberror)
                {
                    if (completion) completion(NO, dberror);
                    return;
                }
                
                // Will return early if input is an empty list.
                [self.backend loadTransactions:[txidsToUpdate allObjects] completion:^(NSArray *transactions, NSError *error) {

                    [self handleNewTransactions:transactions completion:^(BOOL success, NSError *error) {
                        // If we did not fail, then we have processed new transactions and foundAny = YES.
                        // We checked if transactions is non-empty array above.
                        if (completion) completion(success, error);
                    }];
                    
                }]; // load txs for txids
            }); // back on main queue
        }); // in bg queue
    }]; // loadUnspentOutputsForAddresses

}

- (void) updateYoungTransactions:(void(^)(BOOL success, NSError* error))completion
{
    const NSInteger maxConfirmations = 5;
    NSInteger height = self.wallet.blockchainHeight - maxConfirmations + 1;

    [self.wallet asyncInDatabase:^id(FMDatabase *db, NSError **dberrorOut) {

        return [MYCTransaction loadRecentTransactionsSinceHeight:height account:self.account.accountIndex database:db];

    } completion:^(NSArray* recentTxs, NSError *dberror) {

        if (recentTxs.count == 0)
        {
            if (completion) completion(YES, nil);
            return;
        }

        NSMutableDictionary* mtxByTxID = [NSMutableDictionary dictionary];
        for (MYCTransaction* mtx in recentTxs)
        {
            mtxByTxID[mtx.transactionID] = mtx;
        }

        NSArray* txids = [mtxByTxID allKeys];
        MYCLog(@"MYCUpdateAccountOperation: updating young transactions (%@): %@", @(txids.count), txids);

        // Checks status of the given transaction IDs and returns an array of dictionaries.
        // Each dictionary is of this format: {@"txid": @"...", @"found": @YES/@NO, @"height": @123, @"date": NSDate }.
        // * `txid` key corresponds to the transaction ID in the array of `txids`.
        // * `found` contains YES if transaction is found and NO otherwise.
        // * `height` contains -1 for unconfirmed transaction and block height at which it is included.
        // * `date` contains time when transaction is recorded or noticed.
        // In case of error, `dicts` is nil and `error` contains NSError object.
        [self.backend loadStatusForTransactions:txids completion:^(NSArray *dicts, NSError *error) {

            if (!dicts)
            {
                if (completion) completion(NO, error);
                return;
            }

            for (NSDictionary* dict in dicts)
            {
                BOOL found = [dict[@"found"] boolValue];
                NSString* txid = dict[@"txid"];
                NSInteger height = [dict[@"height"] integerValue];
                NSDate* date = dict[@"date"];

                MYCTransaction* mtx = mtxByTxID[txid];

                if (!mtx)
                {
                    MYCError(@"MYCUpdateAccountOperation: received status for txid which was not in the list of recent transactions: %@", txid);
                    continue;
                }

                if (!found)
                {
                    // We have a transaction locally that does not exist in the
                    // blockchain. Must be a residue due to double-spend or malleability
                    [self.wallet inDatabase:^(FMDatabase *db) {
                        NSError* dberror = nil;
                        if (![mtx deleteFromDatabase:db error:&dberror])
                        {
                            MYCError(@"MYCUpdateAccountOperation: failed to remove MYCTransaction from DB: %@ (account %@)", txid, @(self.account.accountIndex));
                        }
                    }];
                    continue;
                }

                // If height or time differs, update the stored transaction.
                if (mtx.blockHeight != height || ABS([date timeIntervalSinceDate:mtx.date]) >= 1.0)
                {
                    // The transaction got a new height or timestamp. There could be
                    // several reasons for that. It got a new timestamp from the server,
                    // it confirmed, or might also be a reorg.

                    MYCLog(@"MYCUpdateAccountOperation: updating transaction %@ with height: %@ -> %@ and date: %@ -> %@",
                           txid, @(mtx.blockHeight), @(height), mtx.date, date);

                    mtx.blockHeight = height;
                    mtx.date = date;

                    [self.wallet inDatabase:^(FMDatabase *db) {
                        NSError* dberror = nil;
                        if (![mtx insertInDatabase:db error:&dberror])
                        {
                            MYCError(@"MYCUpdateAccountOperation: failed to update MYCTransaction in DB: %@ (account %@)", txid, @(self.account.accountIndex));
                        }
                    }];
                } // if tx is updated
            } // foreach status dict.


            if (completion) completion(YES, nil);
        }];
    }];
}




- (void) updateLocalBalance:(void(^)(BOOL success, NSError* error))completion
{
    [self.wallet asyncInTransaction:^id(FMDatabase *db, BOOL *rollback, NSError *__autoreleasing *dberrorOut) {

        BTCSatoshi confirmed = 0;
        BTCSatoshi pendingChange = 0;
        BTCSatoshi pendingSending = 0;
        BTCSatoshi pendingReceiving = 0;

        NSArray* /* [MYCUnspentOutput] */ unspentOutputs = [MYCUnspentOutput loadOutputsForAccount:self.account.accountIndex database:db];

        // 1. Determine the value we are receiving and create a set of outpoints for fast lookup

        NSMutableSet* unspentOutpoints = [NSMutableSet set];
        for (MYCUnspentOutput* output in unspentOutputs)
        {
            // Unconfirmed output
            if (output.blockHeight == -1)
            {
                // Check if any input of transaction identified by output.transactionHash is spending existing MYCParentOutput.
                if ([self isTxSpentByMe:output.outpointHash database:db])
                {
                    pendingChange += output.value;
                }
                else
                {
                    pendingReceiving += output.value;
                }
            }
            else
            {
                confirmed += output.value;
            }
            [unspentOutpoints addObject:output.outpoint];
        }


        // 2. Determine the value we are sending


        // Get the current set of unconfirmed transactions
        for (MYCTransaction* unconfirmedMtx in [MYCTransaction loadUnconfirmedTransactionsForAccount:self.account.accountIndex database:db])
        {
            BTCTransaction* tx = unconfirmedMtx.transaction;

            // For each input figure out if WE are sending it by fetching the
            // parent transaction and looking at the address
            for (BTCTransactionInput* txin in tx.inputs)
            {
                // Find the parent transaction
                if (txin.isCoinbase) continue;

                MYCParentOutput* parent = [MYCParentOutput loadOutputForAccount:self.account.accountIndex hash:txin.previousHash index:txin.previousIndex database:db];

                if (parent)
                {
                    if ((parent.change >= 0 && parent.keyIndex >= 0))
                    {
                        // Have parent with valid key path - we fund this transaction
                        pendingSending += parent.value;
                    }
                }
                else
                {
                    MYCError(@"No parent output for input %@:%@", txin.previousTransactionID, @(txin.previousIndex));
                }
            }

            // Now look at the outputs and if it contains change for us, then subtract that from the sending amount
            // if it is already spent in another transaction.
            for (NSInteger i = 0; i < tx.outputs.count; i++)
            {
                BTCTransactionOutput* output = tx.outputs[i];

                // If spent by us.
                if ([self.account matchesScriptData:output.script.data change:NULL keyIndex:NULL])
                {
                    BTCOutpoint* outpoint = [[BTCOutpoint alloc] initWithHash:tx.transactionHash index:(uint32_t)i];

                    // Note: this outpoint could be already counted as change or confirmed balance in unspent outputs.
                    // However, here it could have been already spent. In such case we need to substract it from sent amount.
                    if (![unspentOutpoints containsObject:outpoint])
                    {
                        // This output has been spent, subtract it from the amount sent.
                        pendingSending -= output.value;

                        if (pendingSending < 0)
                        {
                            MYCError(@"OMG! pendingSending is below zero! %@", @(pendingSending));
                        }
                    }
                }
            }
        } // foreach unconfirmed tx

        NSString* prevBalanceDesc = [self.account debugBalanceDescription];

        self.account.confirmedAmount = confirmed;
        self.account.pendingChangeAmount = pendingChange;
        self.account.pendingReceivedAmount = pendingReceiving;
        self.account.pendingSentAmount = pendingSending;

        NSString* currBalanceDesc = [self.account debugBalanceDescription];

        if (![prevBalanceDesc isEqualToString:currBalanceDesc])
        {
            MYCLog(@"MYCUpdateAccountOperation[%@]: Updated account balance:", @(self.account.accountIndex));
            MYCLog(@"MYCUpdateAccountOperation[%@]: BEFORE: %@", @(self.account.accountIndex), prevBalanceDesc);
            MYCLog(@"MYCUpdateAccountOperation[%@]:  AFTER: %@", @(self.account.accountIndex), currBalanceDesc);
        }
        else
        {
            MYCLog(@"MYCUpdateAccountOperation[%@]: Balance did not change.", @(self.account.accountIndex));
        }

        NSError* dberror = nil;
        if (![self.account saveInDatabase:db error:&dberror])
        {
            dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error while updating account balance."}];
            MYCError(@"MYCWallet: failed to save account %d after updating local balance: %@", (int)self.account.accountIndex, dberror);

            if (rollback) *rollback = YES;
            if (dberrorOut) *dberrorOut = dberror;
            return nil;
        }

        return @1;

    } completion:^(id result, NSError *dberror) {

        if (completion) completion(!!result, dberror);

    }];
}


- (BOOL) isTxSpentByMe:(NSData*)transactionHash database:(FMDatabase*)db
{
    if (!transactionHash) return NO;

    MYCTransaction* tx = [MYCTransaction loadTransactionWithHash:transactionHash account:self.account.accountIndex database:db];

    if (!tx) return NO;

    for (BTCTransactionInput* input in tx.transaction.inputs)
    {
        // We store only our parent outputs so here it's enough to just check if one exists.
        MYCParentOutput* parentOutput = [MYCParentOutput loadOutputForAccount:self.account.accountIndex hash:input.previousHash index:input.previousIndex database:db];
        if (parentOutput.change >= 0 && parentOutput.keyIndex >= 0)
        {
            return YES;
        }
    }
    return NO;
}






#pragma mark - Discover Addresses





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

    BTCKeychain* externalKeychain = self.account.externalKeychain;
    BTCKeychain* internalKeychain = self.account.internalKeychain;
    for (int i = 0; i <= self.externalAddressesLookAhead; i++)
    {
        BTCKey* key = [externalKeychain keyAtIndex:(uint32_t)self.latestExternalIndex + i hardened:NO];
        if (key) [addresses addObject:[self.wallet addressForKey:key]];
    }
    for (int i = 0; i <= self.internalAddressesLookAhead; i++)
    {
        BTCKey* key = [internalKeychain keyAtIndex:(uint32_t)self.latestInternalIndex + i hardened:NO];
        if (key) [addresses addObject:[self.wallet addressForKey:key]];
    }

    // Load all known transactions for the given addresses.
    [self.backend loadTransactionIDsForAddresses:addresses limit:1000 completion:^(NSArray *txids, NSInteger height, NSError *error) {

        if (!txids)
        {
            if (completion) completion(NO, 0, error);
            return;
        }

        // Update blockchain height for usage throughout the app.
        [self log:[NSString stringWithFormat:@"Updating blockchain height: %d", (int)height]];
        self.wallet.blockchainHeight = height;

        // Will return early if input is empty list.
        [self.backend loadTransactions:txids completion:^(NSArray *transactions, NSError *error) {

            if (!transactions)
            {
                if (completion) completion(NO, NO, error);
                return;
            }

            // Found no transactions, return early with foundAny = NO.
            if (transactions.count == 0)
            {
                if (completion) completion(YES, NO, nil);
                return;
            }

            [self handleNewTransactions:transactions completion:^(BOOL success, NSError *error) {
                // If we did not fail, then we have processed new transactions and foundAny = YES.
                // We checked if transactions is non-empty array above.
                if (completion) completion(success, success, error);
            }];

        }]; // load txs for txids
    }]; // load txids for addresses
}



- (void) handleNewTransactions:(NSArray*)transactions completion:(void(^)(BOOL success, NSError* error))completion
{
    // If have no transactions, return early.
    if (transactions.count == 0)
    {
        if (completion) completion(YES, nil);
        return;
    }

    [self saveTransactions:transactions completion:^(BOOL success, NSError *error) {

        if (!success)
        {
            if (completion) completion(NO, error);
            return;
        }

        // Fetch parent outputs.
        // Parent outputs are used to figure which inputs are ours when we compute balance.
        // Technically, we could assume all payments to be P2PKH and extract pubkey from the input without fetching parent outputs,
        // but for consistency and extensibility we check the destination via the output script.
        [self fetchRelevantParentOutputsFromTransactions:transactions completion:^(BOOL success, NSError *error) {

            if (completion) completion(success, error);

        }];
    }]; // save txs.
}



- (void) fetchRelevantParentOutputsFromTransactions:(NSArray*)txs completion:(void(^)(BOOL success, NSError* error))completion
{
    NSInteger accountIndex = self.account.accountIndex;
    MYCWallet* wallet = self.wallet;

    MYCLog(@"DEBUG fetchRelevantParentOutputsFromTransactions: %@", [txs valueForKey:@"transactionID"]);

    // Perform DB loads on background thread.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

        NSMutableSet* txidsToFetch = [NSMutableSet set];

        NSMutableDictionary* parentOutputsByOutpoint = [NSMutableDictionary dictionary]; // [ BTCOutpoint : BTCTransactionOutput ]
        NSMutableDictionary* parentTxsByHash = [NSMutableDictionary dictionary]; // [ NSData : BTCTransaction ]

        [wallet inDatabase:^(FMDatabase *db) {
            for (BTCTransaction* tx in txs)
            {
                // Ignore coinbase transactions - they don't have parent txs.
                if (tx.isCoinbase)
                {
                    MYCLog(@"Skipping coinbase tx.");
                    continue;
                }

                for (BTCTransactionInput* txin in tx.inputs)
                {
                    MYCLog(@"Checking parents for txin: %@:%@", txin.previousTransactionID, @(txin.previousIndex));
                    MYCParentOutput* parentOutput = [MYCParentOutput loadOutputForAccount:accountIndex hash:txin.previousHash index:txin.previousIndex database:db];

                    if (parentOutput)
                    {
                        // We already have a parent output, no need to fetch the entire parent transaction.
                        //MYCLog(@"We already have a parent output, no need to fetch the entire parent transaction: %@:%@", txin.previousTransactionID, @(txin.previousIndex));
                        parentOutputsByOutpoint[txin.outpoint] = parentOutput.transactionOutput;
                        continue;
                    }

                    MYCTransaction* parentTx = [MYCTransaction loadTransactionWithHash:txin.previousHash account:accountIndex database:db];

                    if (parentTx)
                    {
                        // We had the parent transaction in our own transactions, no need to fetch it remotely.
                        //MYCLog(@"We had the parent transaction in our own transactions, no need to fetch it remotely: %@", parentTx.transactionID);
                        BTCTransaction* btctx = parentTx.transaction;
                        parentTxsByHash[btctx.transactionHash] = btctx;
                    }
                    else
                    {
                        // No parent transaction - lets fetch it.
                        [txidsToFetch addObject:txin.previousTransactionID];
                    }
                }
            }
        }];

        //MYCLog(@"txidsToFetch: %@", txidsToFetch);

        // Continue on main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            // Fetch parent transactions and put them in parentTxsByHash.
            [self.backend loadTransactions:[txidsToFetch allObjects] completion:^(NSArray *transactions, NSError *error) {

                // Here we may get no new transactions, but we may have some in parentTxsByHash.

                for (BTCTransaction* btctx in transactions)
                {
                    parentTxsByHash[btctx.transactionHash] = btctx;
                }

                // Then find all outputs relevant to us and if they are not stored already,
                // save in database as parent outputs.

                // We should now have all parent transactions or parent outputs. There is
                // a slight probability that one of them won't be found due to double
                // spends and/or malleability and network latency etc.

                // Enumerate again all inputs that we started with and try to save matching outputs that we found.
                NSMutableArray* outputsToSave = [NSMutableArray array];
                for (BTCTransaction* tx in txs)
                {
                    // Ignore coinbase transactions - they don't have parent txs.
                    if (tx.isCoinbase)
                    {
                        MYCLog(@"Skipping coinbase tx.");
                        continue;
                    }

                    for (BTCTransactionInput* txin in tx.inputs)
                    {
                        BTCTransactionOutput* txout = parentOutputsByOutpoint[txin.outpoint];
                        if (txout)
                        {
                            // We have it already
                            MYCLog(@"MYCUpdateAccountOperation: parent output %@:%@ already found for this account %@",
                                   txin.previousTransactionID, @(txin.previousIndex), @(accountIndex));
                            continue;
                        }
                        BTCTransaction* parentTx = parentTxsByHash[txin.previousHash];

                        // Normally this is always true except when we have double-spends or network latency etc.
                        if (parentTx)
                        {
                            // Take parent output from the parent transaction.
                            if (txin.previousIndex < parentTx.outputs.count)
                            {
                                BTCTransactionOutput* parentOutput = parentTx.outputs[txin.previousIndex];
                                parentOutput.blockHeight = parentTx.blockHeight;
                                parentOutput.transactionHash = parentTx.transactionHash;
                                parentOutput.index = txin.previousIndex;

                                // Check if this output actually belongs to this account.
                                NSInteger change = -1;
                                NSInteger keyIndex = -1;
                                if ([self.account matchesScriptData:parentOutput.script.data change:&change keyIndex:&keyIndex])
                                {
                                    parentOutput.userInfo = @{@"change": @(change), @"keyIndex": @(keyIndex) };
                                    MYCLog(@"MYCUpdateAccountOperation: parent output %@:%@ is detected to be used in the account %@",
                                           BTCTransactionIDFromHash(parentOutput.transactionHash), @(parentOutput.index), @(accountIndex));
                                }
                                else
                                {
                                    parentOutput.userInfo = @{@"change": @(-1), @"keyIndex": @(-1) };
                                    MYCLog(@"MYCUpdateAccountOperation: parent output %@:%@ not used in the account %@",
                                           BTCTransactionIDFromHash(parentOutput.transactionHash), @(parentOutput.index), @(accountIndex));
                                }

                                // Save both ours and foreign parent outputs so we can show full details in transaction history.
                                [outputsToSave addObject:parentOutput];
                            }
                            else
                            {
                                MYCError(@"MYCUpdateAccountOperation: broken parent transaction with txin.previousIndex exceeding parent tx outputs!");
                            }
                        }
                        else
                        {
                            MYCError(@"MYCUpdateAccountOperation: parent transaction not found: %@", txin.previousTransactionID);
                        }
                    }
                }

                // Perform DB updates on background thread.
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

                    __block NSError* dberror = nil;
                    [wallet inDatabase:^(FMDatabase *db) {
                        for (BTCTransactionOutput* txout in outputsToSave)
                        {
                            MYCParentOutput* mpout = [[MYCParentOutput alloc] init];

                            mpout.transactionOutput = txout;
                            mpout.accountIndex = accountIndex;
                            mpout.change = [txout.userInfo[@"change"] integerValue];
                            mpout.keyIndex = [txout.userInfo[@"keyIndex"] integerValue];

                            if (![mpout insertInDatabase:db error:&dberror])
                            {
                                dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error"}];
                                MYCError(@"MYCUpdateAccountOperation: failed to save transaction output %@ for account %d in database: %@", txout, (int)accountIndex, dberror);
                                return;
                            }
                            else
                            {
                                MYCLog(@"MYCUpdateAccountOperation: saved parent output %@:%d", BTCTransactionIDFromHash(txout.transactionHash), (int)txout.index);
                            }
                        }
                    }];

                    // Continue on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{

                        if (completion) completion(!dberror, dberror);
                        return;

                    }); // on main thread
                });// on bg thread
            }]; // loaded txs
        }); // on main thread
    });// on bg thread
}




#pragma mark - Save and Update Transactions




// Saves new transactions relevant to this account and updates key indexes based on which keys are found to be used.
- (void) saveTransactions:(NSArray*)txs completion:(void(^)(BOOL success, NSError* error))completion
{
    NSInteger accountIndex = self.account.accountIndex;
    MYCWallet* wallet = self.wallet;

    // We'll use these to advance indices
    NSInteger externalStartIndex = self.latestExternalIndex;
    NSInteger internalStartIndex = self.latestInternalIndex;

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

            for (BTCTransaction* tx in txs)
            {
                MYCTransaction* mtx = [[MYCTransaction alloc] init];

                mtx.transactionHash = tx.transactionHash;
                mtx.data            = tx.data;
                mtx.blockHeight     = tx.blockHeight;
                mtx.date            = tx.blockDate;
                mtx.accountIndex    = accountIndex;

                NSError* dberror = nil;
                if (![mtx insertInDatabase:db error:&dberror])
                {
                    error = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error"}];
                    MYCError(@"MYCWallet: failed to save transaction %@ for account %d in database: %@", tx.transactionID, (int)accountIndex, dberror);
                    return;
                }
                else
                {
                    MYCLog(@"MYCUpdateAccountOperation: saved transaction: %@", tx.transactionID);
                }

                for (BTCTransactionOutput* txout in tx.outputs)
                {
                    NSData* blob = txout.script.data;
                    NSUInteger i = [self.account externalIndexForScriptData:blob startIndex:externalStartIndex limit:self.externalAddressesLookAhead + 1];
                    if (i != NSNotFound)
                    {
                        externalCurrentIndex = MAX(externalCurrentIndex, (NSInteger)i);
                        //MYCLog(@"BUMP externalCurrentIndex = %@", @(externalCurrentIndex));
                    }
                    else
                    {
                        i = [self.account internalIndexForScriptData:blob startIndex:internalStartIndex limit:self.internalAddressesLookAhead + 1];
                        if (i != NSNotFound)
                        {
                            internalCurrentIndex = MAX(internalCurrentIndex, (NSInteger)i);
                            //MYCLog(@"BUMP internalCurrentIndex = %@", @(internalCurrentIndex));
                        }
                    }
                } // for each txout
            } // for each tx

            // We normally do not fail to write txs into DB, so it's okay to advance indexes once we iterated over all transactions.
            if (externalCurrentIndex >= 0 || internalCurrentIndex >= 0)
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
            else
            {
                //MYCLog(@"NOT BUMPED ANY current index");
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
