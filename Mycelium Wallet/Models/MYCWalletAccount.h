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

@property(nonatomic) uint32_t externalKeyIndex;
@property(nonatomic) uint32_t internalKeyIndex;
@property(nonatomic, getter=isArchived) BOOL archived;
@property(nonatomic, getter=isCurrent) BOOL current;
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

- (id) initWithKeychain:(BTCKeychain*)keychain;



@end
