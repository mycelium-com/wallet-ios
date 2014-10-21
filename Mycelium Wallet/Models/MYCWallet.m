//
//  MYCWallet.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWallet.h"
#import "MYCUnlockedWallet.h"
#import "MYCWalletAccount.h"
#import "MYCDatabase.h"
#import "MYCBackend.h"
#import "MYCDatabaseMigrations.h"
#import "MYCUpdateAccountOperation.h"

NSString* const MYCWalletFormatterDidUpdateNotification = @"MYCWalletFormatterDidUpdateNotification";
NSString* const MYCWalletCurrencyConverterDidUpdateNotification = @"MYCWalletCurrencyConverterDidUpdateNotification";
NSString* const MYCWalletDidReloadNotification = @"MYCWalletDidReloadNotification";
NSString* const MYCWalletDidUpdateNetworkActivityNotification = @"MYCWalletDidUpdateNetworkActivityNotification";
NSString* const MYCWalletDidUpdateAccountNotification = @"MYCWalletDidUpdateAccountNotification";

@interface MYCWallet ()
@property(nonatomic) NSURL* databaseURL;

// Returns current database configuration.
// Returns nil if database is not created yet.
- (MYCDatabase*) database;

@end

@implementation MYCWallet {
    MYCDatabase* _database;
    int _updatingExchangeRate;
    NSMutableArray* _accountUpdateOperations;
}

+ (instancetype) currentWallet
{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id) init
{
    if (self = [super init])
    {
    }
    return self;
}

- (BOOL) isTestnet
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"MYCWalletTestnet"];
}

- (void) setTestnet:(BOOL)testnet
{
    if (self.testnet == testnet) return;

    [[NSUserDefaults standardUserDefaults] setBool:testnet forKey:@"MYCWalletTestnet"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (_database)
    {
        _database = [self openDatabase];

        // Database does not exist for this configuration.
        // Lets load mnemonic
        if (!_database)
        {
            MYCLog(@"MYCWallet: loading mnemonic to create another database for %@", testnet ? @"testnet" : @"mainnet");
            [self unlockWallet:^(MYCUnlockedWallet *uw) {
                _database = [self openDatabaseOrCreateWithMnemonic:uw.mnemonic];
            } reason:NSLocalizedString(@"Authorize access to master key to switch testnet mode", @"")];
        }
    }
}

- (void) setTestnetOnce
{
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletTestnet"])
    {
        self.testnet = YES;
    }
}

- (BOOL) isBackedUp
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"MYCWalletBackedUp"];
}

- (void) setBackedUp:(BOOL)backedUp
{
    [[NSUserDefaults standardUserDefaults] setBool:backedUp forKey:@"MYCWalletBackedUp"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BTCNumberFormatterUnit) bitcoinUnit
{
    NSNumber* num = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletBitcoinUnit"];
    if (!num) return BTCNumberFormatterUnitBit;
    return [num unsignedIntegerValue];
}

- (void) setBitcoinUnit:(BTCNumberFormatterUnit)bitcoinUnit
{
    [[NSUserDefaults standardUserDefaults] setObject:@(bitcoinUnit) forKey:@"MYCWalletBitcoinUnit"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.btcFormatter.bitcoinUnit = bitcoinUnit;
}

- (BTCNumberFormatter*) btcFormatter
{
    if (!_btcFormatter)
    {
        _btcFormatter = [[BTCNumberFormatter alloc] initWithBitcoinUnit:self.bitcoinUnit symbolStyle:BTCNumberFormatterSymbolStyleLowercase];
    }
    return _btcFormatter;
}

- (NSNumberFormatter*) fiatFormatter
{
    if (!_fiatFormatter)
    {
        // For now we only support USD, but will have to support various currency exchanges later.
        _fiatFormatter = [[NSNumberFormatter alloc] init];
        _fiatFormatter.lenient = YES;
        _fiatFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        _fiatFormatter.currencyCode = @"USD";
        _fiatFormatter.groupingSize = 3;
        _fiatFormatter.currencySymbol = [NSLocalizedString(@"USD", @"") lowercaseString];
        _fiatFormatter.internationalCurrencySymbol = _fiatFormatter.currencySymbol;

        _fiatFormatter.positivePrefix = @"";
        _fiatFormatter.positiveSuffix = [@"\xE2\x80\xAF" stringByAppendingString:_fiatFormatter.currencySymbol];
        _fiatFormatter.negativeFormat = [_fiatFormatter.positiveFormat stringByReplacingCharactersInRange:[_fiatFormatter.positiveFormat rangeOfString:@"#"] withString:@"-#"];
    }
    return _fiatFormatter;
}

- (BTCCurrencyConverter*) currencyConverter
{
    if (!_currencyConverter)
    {
        NSDictionary* dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletCurrencyConverter"];

        _currencyConverter = [[BTCCurrencyConverter alloc] initWithDictionary:dict];

        if (!_currencyConverter)
        {
            _currencyConverter = [[BTCCurrencyConverter alloc] init];
            _currencyConverter.currencyCode = @"USD";
            _currencyConverter.marketName = @"Bitstamp";
            _currencyConverter.averageRate = [NSDecimalNumber decimalNumberWithString:@"0.0"];
            _currencyConverter.date = [NSDate dateWithTimeIntervalSince1970:0];
        }
    }
    return _currencyConverter;
}

- (void) saveCurrencyConverter
{
    if (!_currencyConverter) return;
    [[NSUserDefaults standardUserDefaults] setObject:_currencyConverter.dictionary forKey:@"MYCWalletCurrencyConverter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.databaseURL.path];
}

- (NSInteger) blockchainHeight
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"MYCWalletBlockchainHeight"];
}

- (void) setBlockchainHeight:(NSInteger)height
{
    [[NSUserDefaults standardUserDefaults] setInteger:height forKey:@"MYCWalletBlockchainHeight"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (MYCBackend*) backend
{
    if (self.isTestnet)
    {
        return [MYCBackend testnetBackend];
    }
    return [MYCBackend mainnetBackend];
}



// Note: this supports only privkey and pubkey hash, not P2SH.
- (BTCPublicKeyAddress*) addressForAddress:(BTCAddress*)address
{
    address = [address publicAddress];
    if (![address isTestnet] == !self.isTestnet)
    {
        return (BTCPublicKeyAddress*)address;
    }
    return [self addressForPublicKeyHash:address.data];
}

- (BTCPublicKeyAddress*) addressForKey:(BTCKey*)key
{
    NSAssert(key.isPublicKeyCompressed, @"BTCKey should be compressed when using BIP32");
    return [self addressForPublicKey:key.publicKey];
}

- (BTCPublicKeyAddress*) addressForPublicKey:(NSData*)publicKey
{
    NSAssert(publicKey.length == 33, @"pubkey should be compact");
    return [self addressForPublicKeyHash:BTCHash160(publicKey)];
}

- (BTCPublicKeyAddress*) addressForPublicKeyHash:(NSData*)hash160
{
    NSAssert(hash160.length == 20, @"160 bit hash should be 20 bytes long");
    if (self.isTestnet)
    {
        return [BTCPublicKeyAddressTestnet addressWithData:hash160];
    }
    return [BTCPublicKeyAddress addressWithData:hash160];
}






- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason
{
    MYCUnlockedWallet* unlockedWallet = [[MYCUnlockedWallet alloc] init];

    unlockedWallet.wallet = self;
    unlockedWallet.reason = reason;

    block(unlockedWallet);

    [unlockedWallet clear];
}








- (MYCDatabase*) database
{
    if (!_database)
    {
        _database = [self openDatabase];
    }
    NSAssert(_database, @"Sanity check");

    return _database;
}

- (NSURL*) databaseURL
{
    return [self databaseURLTestnet:self.isTestnet];
}

- (NSURL*) databaseURLTestnet:(BOOL)istestnet
{
    NSURL *documentsFolderURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *databaseURL = [NSURL URLWithString:[NSString stringWithFormat:@"MyceliumWallet%@.sqlite3", istestnet ? @"Testnet" : @"Mainnet"]
                                relativeToURL:documentsFolderURL];
    return databaseURL;
}

- (void) setupDatabaseWithMnemonic:(BTCMnemonic*)mnemonic
{
    if (!mnemonic)
    {
        [[NSException exceptionWithName:@"MYCWallet cannot setupDatabase without a mnemonic" reason:@"" userInfo:nil] raise];
    }

    [self removeDatabase];

    _database = [self openDatabaseOrCreateWithMnemonic:mnemonic];
}

- (MYCDatabase*) openDatabase
{
    return [self openDatabaseOrCreateWithMnemonic:nil];
}

- (MYCDatabase*) openDatabaseOrCreateWithMnemonic:(BTCMnemonic*)mnemonic
{
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];

    // Create database

    MYCDatabase *database = nil;

    NSURL *databaseURL = self.databaseURL;

    // Do not create DB if we couldn't do that and it does not exist yet.
    // We should only allow opening the existing DB (when mnemonic is nil) or
    // creating a new one (when mnemonic is not nil).
    if (!mnemonic && ![fm fileExistsAtPath:databaseURL.path])
    {
        return nil;
    }

    MYCLog(@"MYCWallet: opening a database at %@", databaseURL.absoluteString);

    database = [[MYCDatabase alloc] initWithURL:databaseURL];
    NSAssert([fm fileExistsAtPath:databaseURL.path], @"Database file does not exist");

    // Database file flags
    {
        // Encrypt database file
        if (![fm setAttributes:@{ NSFileProtectionKey: NSFileProtectionComplete }
                  ofItemAtPath:database.URL.path
                         error:&error])
        {
            [NSException raise:NSInternalInconsistencyException format:@"Can not protect database file (%@)", error];
        }

        // Prevent database file from iCloud backup
        if (![database.URL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error])
        {
            [NSException raise:NSInternalInconsistencyException format:@"Can not exclude database file from backup (%@)", error];
        }
    }

    // Register model migrations

    [MYCDatabaseMigrations registerMigrations:database];


    // Create default account

    [database registerMigration:@"createDefaultAccount" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {

        BTCKeychain* bitcoinKeychain = self.isTestnet ? mnemonic.keychain.bitcoinTestnetKeychain : mnemonic.keychain.bitcoinMainnetKeychain;

        MYCWalletAccount* account = [[MYCWalletAccount alloc] initWithKeychain:[bitcoinKeychain keychainForAccount:0]];

        NSAssert(account, @"Must be a valid account");

        account.label = NSLocalizedString(@"Main Account", @"");
        account.current = YES;

        return [account saveInDatabase:db error:outError];
    }];

    
    // Open database

    if (![database open:&error])
    {
        MYCError(@"[%@ %@] error:%@", [self class], NSStringFromSelector(_cmd), error);

        // Could not open the database: suppress the database file, and restart from scratch
        if ([fm removeItemAtURL:database.URL error:&error])
        {
            // Restart. But don't enter infinite loop.
            static int retryCount = 2;
            if (retryCount == 0) {
                [NSException raise:NSInternalInconsistencyException format:@"Give up (%@)", error];
            }
            --retryCount;
            [self openDatabaseOrCreateWithMnemonic:mnemonic];
        }
        else
        {
            [NSException raise:NSInternalInconsistencyException format:@"Give up because can not delete database file (%@)", error];
        }
    }

    // Done

    // Notify on main queue 1) to enforce main thread and 2) to let MYCWallet to assign this database instance to its ivar.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidReloadNotification object:self];
    });

    return database;
}

// Removes database from disk.
- (void) removeDatabase
{
    for (NSURL* dbURL in @[[self databaseURLTestnet:YES], [self databaseURLTestnet:NO]])
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:dbURL.path])
        {
            MYCLog(@"WARNING: MYCWallet is removing Mycelium database from disk: %@", dbURL.absoluteString);
        }

        if (_database) [_database close];

        _database = nil;
        NSError* error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:dbURL error:&error];
    }
    // Do not notify to not break the app.
}

// For debug only: deletes database and re-creates it with a given mnemonic.
- (void) resetDatabase
{
    [self unlockWallet:^(MYCUnlockedWallet *w) {
        BTCMnemonic* mnemonic = w.mnemonic;
        [self removeDatabase];
        _database = [self openDatabaseOrCreateWithMnemonic:mnemonic];
    } reason:@"Authorize access to mnemonic to re-create database."];
}

// Access database
- (void) inDatabase:(void(^)(FMDatabase *db))block
{
    return [self.database inDatabase:block];
}

- (void) inTransaction:(void(^)(FMDatabase *db, BOOL *rollback))block
{
    return [self.database inTransaction:block];
}




#pragma mark - Networking



- (BOOL) isNetworkActive
{
    return self.backend.isActive;
}

- (BOOL) isUpdatingAccounts
{
    return _accountUpdateOperations.count > 0;
}

// Updates exchange rate if needed.
// Set force=YES to force update (e.g. if user tapped 'refresh' button).
- (void) updateExchangeRate:(BOOL)force completion:(void(^)(BOOL success, NSError *error))completion
{
    if (!force)
    {
        if (_updatingExchangeRate)
        {
            if (completion) completion(NO, nil);
            return;
        }
        NSDate* date = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletCurrencyRateUpdateDate"];
        if (date && [date timeIntervalSinceNow] > -300.0)
        {
            // Updated less than 5 minutes ago, so should be up to date.
            if (completion) completion(NO, nil);
            return;
        }
    }

    [self notifyNetworkActivity];

    _updatingExchangeRate++;

    [self.backend loadExchangeRateForCurrencyCode:self.currencyConverter.currencyCode
                                        completion:^(NSDecimalNumber *btcPrice, NSString *marketName, NSDate *date, NSString *nativeCurrencyCode, NSError *error) {

                                            _updatingExchangeRate--;

                                            if (!btcPrice)
                                            {
                                                MYCLog(@"MYCWallet: Failed to update exchange rate: %@", error.localizedDescription);
                                                if (completion) completion(NO, error);
                                                return;
                                            }

                                            // Remember when we last updated it.
                                            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"MYCWalletCurrencyRateUpdateDate"];

                                            self.currencyConverter.averageRate = btcPrice;
                                            self.currencyConverter.marketName = marketName;
                                            if (date) self.currencyConverter.date = date;
                                            self.currencyConverter.nativeCurrencyCode = nativeCurrencyCode ?: self.currencyConverter.currencyCode;

                                            [self saveCurrencyConverter];

                                            if (completion) completion(YES, nil);

                                            [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletCurrencyConverterDidUpdateNotification object:self];

                                            [self notifyNetworkActivity];
                                        }];
}

// Updates a given account.
// Set force=YES to force update (e.g. if user tapped 'refresh' button).
// If update is skipped, completion block is called with (NO,nil).
- (void) updateAccount:(MYCWalletAccount*)account force:(BOOL)force completion:(void(^)(BOOL success, NSError *error))completion
{
    if (!force)
    {
        // If synced less than 5 minutes ago, skip sync.
        if (account.syncDate && [account.syncDate timeIntervalSinceNow] > -300)
        {
            if (completion) completion(NO, nil);
            return;
        }
    }

    if (!_accountUpdateOperations) _accountUpdateOperations = [NSMutableArray array];

    for (MYCUpdateAccountOperation* op in _accountUpdateOperations)
    {
        if (op.account.accountIndex == account.accountIndex)
        {
            // Skipping sync since the operation is already in progress.
            if (completion) completion(NO, nil);
            return;
        }
    }

    MYCUpdateAccountOperation* op = [[MYCUpdateAccountOperation alloc] initWithAccount:account wallet:self];
    [_accountUpdateOperations addObject:op];

    [op update:^(BOOL success, NSError *error) {

        [_accountUpdateOperations removeObject:op];

        if (success)
        {
            [self inDatabase:^(FMDatabase *db) {
                // Make sure we use the latest data and update the sync date.
                [account reloadFromDatabase:db];
                account.syncDate = [NSDate date];
                NSError* dberror = nil;
                if (![account saveInDatabase:db error:&dberror])
                {
                    MYCError(@"MYCWallet: failed to save account with bumped syncDate in database: %@", dberror);
                    if (completion) completion(NO, error);
                    return;
                }
            }];
        }

        if (completion) completion(success, error);

        [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:account];
    }];
}


- (void) notifyNetworkActivity
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateNetworkActivityNotification object:self];
}



@end

