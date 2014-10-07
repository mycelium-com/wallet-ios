//
//  MYCWallet.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>

@class MYCDatabase;

// Unlocked wallet is a transient instance for handling sensitive data.
@interface MYCUnlockedWallet : NSObject

// Root wallet seed encoded as a BIP39 mnemonic.
@property(nonatomic) BTCMnemonic* mnemonic;

// Returns a BIP32 keychain for current wallet configuration (seed/purpose'/coin_type').
// To get an address for a given account, you should drill in with "account'/change/address_index".
@property(nonatomic, readonly) BTCKeychain* keychain;

@end

@interface MYCWallet : NSObject

@property(nonatomic, getter=isTestnet) BOOL testnet;

+ (instancetype) currentWallet;

// Unlocks wallet with a human-readable reason.
- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason;

// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored;

// Returns current database configuration.
// Returns nil if database is not created yet.
- (MYCDatabase*) database;

// Creates database and populates with default account.
- (void) setupDatabaseWithMnemonic:(BTCMnemonic*)mnemonic;

// Removes database from disk.
- (void) removeDatabase;


@end
