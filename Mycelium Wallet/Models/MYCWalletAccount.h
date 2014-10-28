//
//  MYCWalletAccount.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>
#import "MYCDatabaseRecord.h"

@interface MYCWalletAccount : MYCDatabaseRecord

@property(nonatomic) NSInteger  accountIndex;
@property(nonatomic) NSString*  label;
@property(nonatomic) NSString*  extendedPublicKey;

// The sum of the unspent outputs which are confirmed and currently not spent in pending transactions.
@property(atomic) BTCSatoshi confirmedAmount;
@property(atomic) BTCSatoshi pendingChangeAmount; // total unconfirmed outputs on change addresses
@property(atomic) BTCSatoshi pendingReceivedAmount; // total unconfirmed outputs on external addresses
@property(atomic) BTCSatoshi pendingSentAmount; // total unconfirmed outputs spent

// Indices to be used in the next payment for each subchain of keys.
// Normally the latest used index is (externalKeyIndex - 1).
// If no addresses have been used yet, externalKeyIndex is 0.
@property(atomic) uint32_t externalKeyIndex;
@property(atomic) uint32_t internalKeyIndex;

// Earliest unspent change index. This is bumped when we spend all unspents involving this index and earlier ones.
@property(nonatomic) uint32_t internalKeyStartingIndex;

// When account is archived, it's not updated regularly.
@property(nonatomic, getter=isArchived) BOOL archived;

// Current account is the one which displays the address to the user and allows payments.
@property(nonatomic, getter=isCurrent) BOOL current;

// Last time this account was synchronized.
@property(nonatomic) NSDate* syncDate;

// Derived Properties

// Confirmed and unconfirmed amounts combined.
// This is the amount that will equal confirmedAmount once all pending transactions are confirmed.
@property(nonatomic, readonly) BTCSatoshi unconfirmedAmount;

// Confirmed + change amount that you can spend.
// Wallet should prefer spending confirmed outputs first, of course.
@property(nonatomic, readonly) BTCSatoshi spendableAmount;

// Returns pendingReceivedAmount.
@property(nonatomic, readonly) BTCSatoshi receivingAmount;

// Returns pendingSentAmount - pendingChangeAmount
@property(nonatomic, readonly) BTCSatoshi sendingAmount;

- (NSString*) debugBalanceDescription;

// Keychain representing this account.
@property(nonatomic, readonly) BTCKeychain* keychain; // thread-safe

// Keychain m/44'/coin'/accountIndex'/0 for exporting to external services to issue invoices and collect payments.
// This refers to "external chain" in BIP44. Whoever knows this keychain cannot learn change addresses,
// so your privacy leak is limited to invoice addresses.
@property(nonatomic, readonly) BTCKeychain* externalKeychain; // thread-safe

// Keychain m/44'/coin'/accountIndex'/1 for change addresses.
@property(nonatomic, readonly) BTCKeychain* internalKeychain; // thread-safe

// Currently available external address to receive payments on.
@property(nonatomic, readonly) BTCPublicKeyAddress* externalAddress;

// Currently available internal (change) address to receive payments on.
@property(nonatomic, readonly) BTCPublicKeyAddress* internalAddress;

// Initializes account with an root account keychain (m/44'/{account}')
- (id) initWithKeychain:(BTCKeychain*)keychain;

// Returns external index for key that matches output script data.
// If not found, returns NSNotFound.
// `startIndex` is included in search.
// At most `limit` indexes are tried.
- (NSUInteger) externalIndexForScriptData:(NSData*)data startIndex:(NSUInteger)startIndex limit:(NSUInteger)limit; // thread-safe
- (NSUInteger) internalIndexForScriptData:(NSData*)data startIndex:(NSUInteger)startIndex limit:(NSUInteger)limit; // thread-safe

// Check if this script data matches one of the addresses in this account.
// Checks within the window of known used addresses.
// If YES, sets change (0 for external, 1 for internal chain) and keyIndex (index of the address).
- (BOOL) matchesScriptData:(NSData*)scriptData change:(NSInteger*)changeOut keyIndex:(NSInteger*)keyIndexOut;

// Loads current active account from database.
+ (MYCWalletAccount*) loadCurrentAccountFromDatabase:(FMDatabase*)db;

// Loads all accounts from database.
+ (NSArray*) loadAccountsFromDatabase:(FMDatabase*)db;

// Loads a specific account at index from database.
// If account does not exist, returns nil.
+ (MYCWalletAccount*) loadAccountAtIndex:(NSInteger)index fromDatabase:(FMDatabase*)db;


@end
