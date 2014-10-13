//
//  MYCWallet.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCUnlockedWallet.h"

// Posted when any formatter was changed.
extern NSString* const MYCWalletFormatterDidUpdateNotification;

// Posted when currency exchange rate has changed.
extern NSString* const MYCWalletCurrencyConverterDidUpdateNotification;

// Posted when wallet updates internal state and all data must be reloaded from the database.
extern NSString* const MYCWalletDidReloadNotification;

// Posted when network activity begins or ends. See also -isNetworkActive.
extern NSString* const MYCWalletDidUpdateNetworkActivity;


@class MYCBackend;
@class MYCWalletAccount;

@interface MYCWallet : NSObject

// Wallet is a singleton instance.
// Use this method to access it.
+ (instancetype) currentWallet;


// Wallet Configuration


// Returns YES if wallet is opened in testnet mode.
// When the value is changed, wallet re-opens another database and posts
// MYCWalletDidReloadNotification notification.
@property(nonatomic, getter=isTestnet) BOOL testnet;

// Set to YES once the user has backed up the wallet.
@property(nonatomic, getter=isBackedUp) BOOL backedUp;

// Formatter for bitcoin values.
// When formatter changes, notification MYCWalletFormatterDidUpdateNotification is posted.
@property(nonatomic) BTCNumberFormatter* btcFormatter;

// Formatter for current fiat currency.
// When formatter changes, notification MYCWalletFormatterDidUpdateNotification is posted.
@property(nonatomic) NSNumberFormatter* fiatFormatter;

// User-selected bitcoin unit.
// View controllers post MYCWalletFormatterDidUpdateNotification when updating this property.
@property(nonatomic) BTCNumberFormatterUnit bitcoinUnit;

// Currency converter for currently used fiat currency.
// View controllers post MYCWalletCurrencyConverterDidUpdateNotification when updating this property.
@property(nonatomic) BTCCurrencyConverter* currencyConverter;

// Client to Mycelium backend to update state of the wallet.
@property(nonatomic) MYCBackend* backend;

// Sets testnet mode once. Call it in developer build in application:didFinishLaunchingWithOptions:
- (void) setTestnetOnce;

// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored;

// Saves exchange rate persistently.
- (void) saveCurrencyConverter;



// Accessing Secret Data



// Unlocks wallet with a human-readable reason.
- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason;




// Accessing Database


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




// Updating Data


// Returns YES if currently busy doing network activity;
- (BOOL) isNetworkActive;

// Returns YES if currently updating one or more accounts.
- (BOOL) isUpdatingAccounts;

// Updates exchange rate if needed.
// Set force=YES to force update (e.g. if user tapped 'refresh' button).
// If update is skipped, completion block is called with (NO,nil).
- (void) updateExchangeRate:(BOOL)force completion:(void(^)(BOOL success, NSError *error))completion;

// Updates a given account.
// Set force=YES to force update (e.g. if user tapped 'refresh' button).
// If update is skipped, completion block is called with (NO,nil).
- (void) updateAccount:(MYCWalletAccount*)account force:(BOOL)force completion:(void(^)(BOOL success, NSError *error))completion;

@end
