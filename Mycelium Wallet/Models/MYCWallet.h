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
@class MYCTransaction;
@class MYCCurrencyFormatter;
@class MYCMinerFeeEstimations;

@interface MYCWallet : NSObject

// Wallet is a singleton instance.
// Use this method to access it.
+ (instancetype) currentWallet;


// Wallet Configuration


// Returns YES if wallet is opened in testnet mode.
// When the value is changed, wallet re-opens another database and posts
// MYCWalletDidReloadNotification notification.
@property(nonatomic, getter=isTestnet) BOOL testnet;
@property(nonatomic) BTCNetwork* network;

// Set to YES once the user has backed up the wallet.
@property(nonatomic, getter=isBackedUp) BOOL backedUp;

// Set to YES when new wallet process begins and set to NO when completed.
@property(nonatomic) BOOL walletSetupInProgress;

// Set to YES once the user has backed up the wallet.
@property(nonatomic, getter=isMigratedToTouchID) BOOL migratedToTouchID;
@property(nonatomic) NSDate* dateLastAskedAboutMigratingToTouchID;

// Used to remind the user to verify if backup is still accessible and not lost.
@property(nonatomic) NSDate* dateLastAskedToVerifyBackupAccess;

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

// Returns a matching currency formatter among the available ones for a given code.
- (MYCCurrencyFormatter*) currencyFormatterForCode:(NSString*)code;

// E.g. you have "1.23 EUR", it'll be stored as "1.23" and "EUR".
- (NSString*) reformatString:(NSString*)amount forCurrency:(NSString*)currencyCode;

// Updates exchange rate and sends CNWalletDidUpdateCurrencyNotification (object == formatter).
- (void) updateCurrencyFormatter:(MYCCurrencyFormatter*)formatter completionHandler:(void(^)(BOOL result, NSError* error))completionHandler;

// Remembers settings in the currency formatter.
- (void) saveCurrencyFormatter:(MYCCurrencyFormatter*)formatter;

// Selects this formatter as a primary one. Sends CNWalletDidUpdateCurrencyNotification.
- (void) selectPrimaryCurrencyFormatter:(MYCCurrencyFormatter*)formatter;

- (void) loadMinerFeeEstimationsWithCompletion:(void(^)(MYCMinerFeeEstimations* estimations, NSError* error))completion;

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

- (BOOL) isTouchIDEnabled;
- (BOOL) isDevicePasscodeEnabled;

// Returns YES if the keychain or file data is stored correctly.
- (BOOL) verifySeedIntegrity;

- (void) makeFileBasedSeedIfNeeded:(void(^)(BOOL result, NSError* error))completionBlock DEPRECATED_ATTRIBUTE;
- (void) migrateToTouchID:(void(^)(BOOL result, NSError* error))completionBlock DEPRECATED_ATTRIBUTE;

// Unlocks wallet with a human-readable reason.
- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason;

// Uses LocalAuthentication API to auth with TouchID if it's available and enabled.
// If user has only passcode or not passcode, then the block is simply being called without extra checks.s
- (void) bestEffortAuthenticateWithTouchID:(void(^)(MYCUnlockedWallet* uw, BOOL authenticated))block reason:(NSString*)reason;



// Managing the automatic backup

- (NSString*) backupWalletID;
- (BTCKey*) backupAuthenticationKey;
- (NSData*) backupKey;
- (NSData*) backupData;

- (void) uploadAutomaticBackup:(void(^)(BOOL result, NSError* error))completionBlock;

- (void) downloadAutomaticBackup:(void(^)(BOOL result, NSError* error))completionBlock;

- (void) setNeedsBackup;

// Force backup if needed.
- (void) backupIfNeeded;

// Returns and erases most recent error during backup.
// So the UI can show the user "Cannot backup, please check your network or iCloud settings."
- (NSError*) popBackupError;
- (BOOL) showLastBackupErrorAlertIfNeeded;


// Accessing Database


// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored;

// Creates database and populates with default account.
- (void) setupDatabaseWithMnemonic:(BTCMnemonic*)mnemonic;


// DEBUGGING API

// Closes, exports DB file and reopens DB again.
- (NSData*) exportDatabaseData;

// Closes, writes data to DB path and reopens it.
- (void) importDatabaseData:(NSData*)data;

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
- (void) updateActiveAccountsForce:(BOOL)force completionBlock:(void(^)(BOOL success, NSError *error))completion;

// Discover accounts with a sliding window. Since accounts' keychains are derived in a hardened mode,
// we need a root keychain with private key to derive accounts' addresses.
// Newly discovered accounts are created automatically with default names.
- (void) discoverAccounts:(BTCKeychain*)rootKeychain completion:(void(^)(BOOL success, NSError *error))completion;

// Updates tx details with up-to-date fiat amount and code.
// If force is NO, it will note overwrite existing record should it exist already.
- (void) updateFiatAmountForTransaction:(MYCTransaction*)tx force:(BOOL)force database:(FMDatabase *)db;

// Returns YES if this new account if within a window of empty accounts.
- (BOOL) canAddAccount;


// Diagnostics

@property(nonatomic, readonly) NSString* diagnosticsLog;

- (void) log:(NSString*)message;
- (void) logError:(NSString*)message;

@end
