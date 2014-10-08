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

// Derived properties.
@property(nonatomic, readonly) BTCKeychain* keychain;

// Currently available external address to receive payments on.
@property(nonatomic, readonly) BTCPublicKeyAddress* externalAddress;

// Currently available internal (change) address to receive payments on.
@property(nonatomic, readonly) BTCPublicKeyAddress* changeAddress;

- (id) initWithKeychain:(BTCKeychain*)keychain;



@end
