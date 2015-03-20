//
//  MYCWallet.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCUnlockedWallet.h"

// Posted when currency exchange rate has changed.
extern NSString* const MYCWalletCurrencyDidUpdateNotification;

// Posted when wallet updates internal state and all data must be reloaded from the database.
extern NSString* const MYCWalletDidReloadNotification;

// Posted when network activity begins or ends. See also -isNetworkActive.
extern NSString* const MYCWalletDidUpdateNetworkActivityNotification;

// Posted when account was updated. Object is MYCWalletAccount.
extern NSString* const MYCWalletDidUpdateAccountNotification;

// Switches between fiat or bitcoin.
// If BTC selected, uses separately selected units.
// If fiat selected, uses the fiat currency selected in settings.
typedef NS_ENUM(NSInteger, MYCWalletPreferredCurrency) {
    MYCWalletPreferredCurrencyBTC = 0,
    MYCWalletPreferredCurrencyFiat = 1,
};

@class MYCBackend;
@class MYCWalletAccount;
@class MYCCurrencyFormatter;

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

// Primary and secondary formatters are typically (btc, fiat) or (fiat, btc).
// When user switches to usd/eur/cny it becomes primary; previous bitcoin formatter (primary or secondary) becomes a secondary one.
// When user switches to btc/mbtc/bits it becomes primary; previous fiat formatter (primary or secondary) becomes a secondary one.
@property(nonatomic, readonly) MYCCurrencyFormatter* primaryCurrencyFormatter;
@property(nonatomic, readonly) MYCCurrencyFormatter* secondaryCurrencyFormatter;

@property(nonatomic, readonly) MYCCurrencyFormatter* fiatCurrencyFormatter;
@property(nonatomic, readonly) MYCCurrencyFormatter* btcCurrencyFormatter;

// Formatter for bitcoin values.
// When formatter changes, notification MYCWalletFormatterDidUpdateNotification is posted.
@property(nonatomic, readonly) BTCNumberFormatter* btcFormatter DEPRECATED_ATTRIBUTE;
@property(nonatomic, readonly) BTCNumberFormatter* btcFormatterNaked DEPRECATED_ATTRIBUTE; // without unit decoration

// Formatter for current fiat currency.
// When formatter changes, notification MYCWalletFormatterDidUpdateNotification is posted.
@property(nonatomic, readonly) NSNumberFormatter* fiatFormatter DEPRECATED_ATTRIBUTE;
@property(nonatomic, readonly) NSNumberFormatter* fiatFormatterNaked DEPRECATED_ATTRIBUTE; // without unit decoration

// User-selected bitcoin unit.
// View controllers post MYCWalletFormatterDidUpdateNotification when updating this property.
@property(nonatomic) BTCNumberFormatterUnit bitcoinUnit DEPRECATED_ATTRIBUTE;

// User-selected BTC-or-Fiat.
@property(nonatomic) MYCWalletPreferredCurrency preferredCurrency DEPRECATED_ATTRIBUTE;

// Current currency converter.
@property(nonatomic, readonly) BTCCurrencyConverter* currencyConverter;

// Array of all supported MYCCurrencyFormatters.
@property(nonatomic, readonly) NSArray* currencyFormatters;

// E.g. you have "1.23 EUR", it'll be stored as "1.23" and "EUR".
- (NSString*) reformatString:(NSString*)amount forCurrency:(NSString*)currencyCode;

// Updates exchange rate and sends CNWalletDidUpdateCurrencyNotification (object == formatter).
- (void) updateCurrencyFormatter:(MYCCurrencyFormatter*)formatter completionHandler:(void(^)(BOOL result, NSError* error))completionHandler;

// Remembers settings in the currency formatter.
- (void) saveCurrencyFormatter:(MYCCurrencyFormatter*)formatter;

// Selects this formatter as a primary one. Sends CNWalletDidUpdateCurrencyNotification.
- (void) selectPrimaryCurrencyFormatter:(MYCCurrencyFormatter*)formatter;


// Date formatters
@property(nonatomic) NSDateFormatter* compactDateFormatter;
@property(nonatomic) NSDateFormatter* compactTimeFormatter;

// Client to Mycelium backend to update state of the wallet.
@property(nonatomic) MYCBackend* backend;

// Latest blockchain height (used to determine confirmations count)
@property(nonatomic) NSInteger blockchainHeight;

// Sets testnet mode once. Call it in developer build in application:didFinishLaunchingWithOptions:
- (void) setTestnetOnce;

// Methods to produce correct testnet/mainnet presentation of the address.
- (BTCPublicKeyAddress*) addressForAddress:(BTCAddress*)address; // converts to testnet or mainnet if needed
- (BTCPublicKeyAddress*) addressForKey:(BTCKey*)key;
- (BTCPublicKeyAddress*) addressForPublicKey:(NSData*)publicKey;
- (BTCPublicKeyAddress*) addressForPublicKeyHash:(NSData*)hash160;


// Accessing Secret Data

// Unlocks wallet with a human-readable reason.
- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason;



// Accessing Database


// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored;

// Creates database and populates with default account.
- (void) setupDatabaseWithMnemonic:(BTCMnemonic*)mnemonic;

// Removes database from disk.
- (void) removeDatabase;

// For debug only: deletes database and re-creates it with a given mnemonic.
- (void) resetDatabase;


// Access database
- (void) inDatabase:(void(^)(FMDatabase *db))block;
- (void) inTransaction:(void(^)(FMDatabase *db, BOOL *rollback))block;

// Runs the db block on background thread and calls the completion block on main thread.
- (void) asyncInDatabase:(id(^)(FMDatabase *db, NSError** dberrorOut))block completion:(void(^)(id result, NSError* dberror))completion;
- (void) asyncInTransaction:(id(^)(FMDatabase *db, BOOL *rollback, NSError** dberrorOut))block completion:(void(^)(id result, NSError* dberror))completion;


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
// Update can be skipped when account was recently updated or when it's already being updated.
- (void) updateAccount:(MYCWalletAccount*)account force:(BOOL)force completion:(void(^)(BOOL success, NSError *error))completion;

// Publishes transaction for this account.
// If transaction broadcast failed, but we can't be sure it didn't reach the server,
// it will be queued and published later.
// queued = YES if transaction was queued and should be broadcasted later.
- (void) broadcastTransaction:(BTCTransaction*)tx fromAccount:(MYCWalletAccount*)account completion:(void(^)(BOOL success, BOOL queued, NSError *error))completion;

// Update all active accounts.
- (void) updateActiveAccounts:(void(^)(BOOL success, NSError *error))completion;

// Discover accounts with a sliding window. Since accounts' keychains are derived in a hardened mode,
// we need a root keychain with private key to derive accounts' addresses.
// Newly discovered accounts are created automatically with default names.
- (void) discoverAccounts:(BTCKeychain*)rootKeychain completion:(void(^)(BOOL success, NSError *error))completion;

// Returns YES if this new account if within a window of empty accounts.
- (BOOL) canAddAccount;

@end
