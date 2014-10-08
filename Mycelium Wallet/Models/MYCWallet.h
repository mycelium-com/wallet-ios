//
//  MYCWallet.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCUnlockedWallet.h"

@class MYCWalletAccount;

@interface MYCWallet : NSObject

@property(nonatomic, getter=isTestnet) BOOL testnet;

+ (instancetype) currentWallet;

// Unlocks wallet with a human-readable reason.
- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason;

// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored;

// Creates database and populates with default account.
- (void) setupDatabaseWithMnemonic:(BTCMnemonic*)mnemonic;

// Removes database from disk.
- (void) removeDatabase;

// Access database
- (void) inDatabase:(void(^)(FMDatabase *db))block;
- (void) inTransaction:(void(^)(FMDatabase *db, BOOL *rollback))block;

// Loads current active account from database.
- (MYCWalletAccount*) currentAccountFromDatabase:(FMDatabase*)db;

// Loads all accounts from database.
- (NSArray*) accountsFromDatabase:(FMDatabase*)db;

// Loads a specific account at index from database.
// If account does not exist, returns nil.
- (MYCWalletAccount*) accountAtIndex:(uint32_t)index fromDatabase:(FMDatabase*)db;

@end
