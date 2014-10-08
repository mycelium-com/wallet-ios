//
//  MYCUnlockedWallet.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 08.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

@class MYCWallet;
// Unlocked wallet is a transient instance for handling sensitive data.
// The only way to access it is to call `-unlockWallet:reason:` on MYCWallet.
@interface MYCUnlockedWallet : NSObject

// Root wallet seed encoded as a BIP39 mnemonic.
@property(nonatomic) BTCMnemonic* mnemonic;

// Returns a BIP32 keychain for current wallet configuration (seed/purpose'/coin_type').
// To get an address for a given account, you should drill in with "account'/change/address_index".
@property(nonatomic) BTCKeychain* keychain;

// Internal properties and methods
@property(nonatomic, weak) MYCWallet* wallet;
@property(nonatomic) NSString* reason;

- (void) clear;

@end
