//
//  MYCConnection.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MYCBroadcastStatus) {
    // Something went wrong with the server or internet connection.
    // Should try re-broadcasting again later.
    MYCBroadcastStatusFailure = 0,

    // Transaction is illformed or double-spend occured.
    // Should not try to re-broadcast this transaction.
    MYCBroadcastStatusBadTransaction  = 400,

    // Transaction is sucessfully broadcasted.
    // No need to broadcast again.
    MYCBroadcastStatusSuccess         = 200,
};


@interface MYCBackend : NSObject

// Returns an instance configured for testnet.
+ (instancetype) testnetBackend;

// Returns an instance configured for mainnet.
+ (instancetype) mainnetBackend;

// Returns YES if currently loading something.
- (BOOL) isActive;


// These APIs are stateless: they only parse JSON and return sensible results.
// It's the job of MYCWallet and related classes to make sense of these results.

// Fetches exchange rate for a given currency code.
- (void) loadExchangeRateForCurrencyCode:(NSString*)currencyCode
                              completion:(void(^)(NSDecimalNumber* btcPrice, NSString* marketName, NSDate* date, NSString* nativeCurrencyCode, NSError* error))completion;

// Fetches unspent outputs (BTCTransactionOutput) for given addresses (BTCAddress instances)
- (void) loadUnspentOutputsForAddresses:(NSArray*)addresses completion:(void(^)(NSArray* outputs, NSInteger height, NSError* error))completion;

// Fetches the latest transaction ids (NSString reversed tx hashes) for given addresses (BTCAddress instances).
// Results include both transactions spending and receiving to the given addresses.
// Default limit is 1000.
- (void) loadTransactionsForAddresses:(NSArray*)addresses completion:(void(^)(NSArray* txids, NSInteger height, NSError* error))completion;
- (void) loadTransactionsForAddresses:(NSArray*)addresses limit:(NSUInteger)limit completion:(void(^)(NSArray* txids, NSInteger height, NSError* error))completion;

// Checks status of the given transaction IDs and returns an array of dictionaries.
// Each dictionary is of this format: {@"txid": @"...", @"found": @YES/@NO, @"height": @123, @"date": NSDate }.
// * `txid` key corresponds to the transaction ID in the array of `txids`.
// * `found` contains YES if transaction is found and NO otherwise.
// * `height` contains -1 for unconfirmed transaction and block height at which it is included.
// * `date` contains time when transaction is recorded or noticed.
// In case of error, `dicts` is nil and `error` contains NSError object.
- (void) loadStatusForTransactions:(NSArray*)txids completion:(void(^)(NSArray* dicts, NSError* error))completion;

// Loads actual transactions (BTCTransaction instances) for given txids.
// Each transaction contains blockHeight property (-1 = unconfirmed) and blockDate property.
- (void) loadTransactions:(NSArray*)txids completion:(void(^)(NSArray* transactions, NSError* error))completion;

// Broadcasts the transaction and returns appropriate status.
// See comments on MYCBroadcastStatus above.
- (void) broadcastTransaction:(BTCTransaction*)tx completion:(void(^)(MYCBroadcastStatus status, NSError* error))completion;


@end
