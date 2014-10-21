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

@property(nonatomic) NSUInteger accountIndex;
@property(nonatomic) NSString*  label;
@property(nonatomic) NSString*  extendedPublicKey;

// The sum of the unspent outputs which are confirmed and currently not spent in pending transactions.
@property(nonatomic) BTCSatoshi confirmedAmount;
@property(nonatomic) BTCSatoshi pendingChangeAmount; // total unconfirmed outputs on change addresses
@property(nonatomic) BTCSatoshi pendingReceivedAmount; // total unconfirmed outputs on external addresses
@property(nonatomic) BTCSatoshi pendingSentAmount; // total unconfirmed outputs spent

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

// Keychain representing this account.
@property(nonatomic, readonly) BTCKeychain* keychain;

// Keychain m/44'/coin'/accountIndex'/0 for exporting to external services to issue invoices and collect payments.
// This refers to "external chain" in BIP44. Whoever knows this keychain cannot learn change addresses,
// so your privacy leak is limited to invoice addresses.
@property(nonatomic, readonly) BTCKeychain* externalKeychain;

// Currently available external address to receive payments on.
@property(nonatomic, readonly) BTCPublicKeyAddress* externalAddress;

// Currently available internal (change) address to receive payments on.
@property(nonatomic, readonly) BTCPublicKeyAddress* changeAddress;

// Initializes account with an root account keychain (m/44'/{account}')
- (id) initWithKeychain:(BTCKeychain*)keychain;

// Loads current active account from database.
+ (MYCWalletAccount*) currentAccountFromDatabase:(FMDatabase*)db;

// Loads all accounts from database.
+ (NSArray*) accountsFromDatabase:(FMDatabase*)db;

// Loads a specific account at index from database.
// If account does not exist, returns nil.
+ (MYCWalletAccount*) accountAtIndex:(uint32_t)index fromDatabase:(FMDatabase*)db;


@end
