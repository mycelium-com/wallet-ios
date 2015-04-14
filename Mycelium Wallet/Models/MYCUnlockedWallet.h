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

// Mnemonic read from a file.
@property(nonatomic) BTCMnemonic* fileBasedMnemonic;

- (BTCMnemonic*) readMnemonic;

@property(nonatomic, readonly) BOOL fileBasedMnemonicIsStored;

- (BOOL) makeFileBasedMnemonic:(BTCMnemonic*)mnemonic;
- (BOOL) makeFileBasedMnemonicIfNeededWithMnemonic:(BTCMnemonic*)mnemonic;

- (BOOL) removeFileBasedMnemonic:(NSString*)reason;


// Returns YES if can successfully read the probe item that does not require user interaction.
@property(nonatomic) BOOL probeItem;

// Returns a BIP32 keychain for current wallet configuration (seed/purpose'/coin_type').
// To get an address for a given account, you should drill in with "account'/change/address_index".
@property(nonatomic) BTCKeychain* keychain;

// Internal properties and methods
@property(nonatomic, weak) MYCWallet* wallet;
@property(nonatomic) NSString* reason;
@property(nonatomic) NSError* error;

+ (void) setBypassMissingPasscode;
+ (BOOL) isPasscodeSet;

- (void) clear;

@end
