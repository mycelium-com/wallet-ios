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
@property(nonatomic) BTCSatoshi confirmedAmount;
@property(nonatomic) BTCSatoshi unconfirmedAmount;
@property(nonatomic) uint32_t externalKeyIndex;
@property(nonatomic) uint32_t internalKeyIndex;
@property(nonatomic, getter=isArchived) BOOL archived;
@property(nonatomic, getter=isCurrent) BOOL current;
@property(nonatomic) NSDate* syncDate;

// Derived Properties

// Confirmed and unconfirmed amounts combined.
@property(nonatomic, readonly) BTCSatoshi combinedAmount;

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
