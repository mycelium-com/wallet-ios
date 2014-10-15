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

NSString* const MYCWalletFormatterDidUpdateNotification = @"MYCWalletFormatterDidUpdateNotification";
NSString* const MYCWalletCurrencyConverterDidUpdateNotification = @"MYCWalletCurrencyConverterDidUpdateNotification";
NSString* const MYCWalletDidReloadNotification = @"MYCWalletDidReloadNotification";
NSString* const MYCWalletDidUpdateNetworkActivity = @"MYCWalletDidUpdateNetworkActivity";

@interface MYCWallet ()
@property(nonatomic) NSURL* databaseURL;

// Returns current database configuration.
// Returns nil if database is not created yet.
- (MYCDatabase*) database;

@end

@implementation MYCWallet {
    MYCDatabase* _database;
    int _updatingExchangeRate;
    int _updatingAccountsTaskCount;
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

- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason
{
    MYCUnlockedWallet* unlockedWallet = [[MYCUnlockedWallet alloc] init];

    unlockedWallet.wallet = self;
    unlockedWallet.reason = reason;

    block(unlockedWallet);

    [unlockedWallet clear];
}

- (MYCBackend*) backend
{
    if (self.testnet)
    {
        return [MYCBackend testnetBackend];
    }
    return [MYCBackend mainnetBackend];
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
    NSURL *documentsFolderURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *databaseURL = [NSURL URLWithString:[NSString stringWithFormat:@"MyceliumWallet%@.sqlite3", self.isTestnet ? @"Testnet" : @"Mainnet"]
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


    // Setup database migrations
    {
        [database registerMigration:@"Create MYCWalletAccounts" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:
                    @"CREATE TABLE MYCWalletAccounts("
                    "accountIndex      INT PRIMARY KEY NOT NULL,"
                    "label             TEXT            NOT NULL,"
                    "extendedPublicKey TEXT            NOT NULL,"
                    "confirmedAmount   INT             NOT NULL,"
                    "unconfirmedAmount INT             NOT NULL,"
                    "archived          INT             NOT NULL,"
                    "current           INT             NOT NULL,"
                    "externalKeyIndex  INT             NOT NULL,"
                    "internalKeyIndex  INT             NOT NULL,"
                    "syncTimestamp     DATETIME                 "
                    ")"];
        }];

        [database registerMigration:@"Create MYCUnspentOutputs" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:
                    @"CREATE TABLE MYCUnspentOutputs("
                    "outpointHash      TEXT NOT NULL,"
                    "outpointIndex     INT  NOT NULL,"
                    "blockHeight       INT  NOT NULL,"
                    "script            TEXT NOT NULL,"
                    "value             INT  NOT NULL,"
                    "accountIndex      INT  NOT NULL,"
                    "keyIndex          INT  NOT NULL," // index of the address used in the keychain
                    "type              TEXT NOT NULL," // unspent, change, receiving
                    "PRIMARY KEY (outpointHash, outpointIndex)"
                    ")"] &&
            [db executeUpdate:
             @"CREATE INDEX MYCUnspentOutputs_accountIndex ON MYCUnspentOutputs (accountIndex)"];
        }];

        [database registerMigration:@"Create MYCTransactionSummaries" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:
                    @"CREATE TABLE MYCTransactionSummaries("
                    "txhash            TEXT NOT NULL,"
                    "data              TEXT NOT NULL,"
                    "blockHeight       INT  NOT NULL,"
                    "accountIndex      INT  NOT NULL,"
                    "PRIMARY KEY (txhash)"
                    ")"]  &&
            [db executeUpdate:
             @"CREATE INDEX MYCTransactionSummaries_accountIndex ON MYCTransactionSummaries (accountIndex)"];
        }];

        [database registerMigration:@"createDefaultAccount" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {

            BTCKeychain* bitcoinKeychain = self.isTestnet ? mnemonic.keychain.bitcoinTestnetKeychain : mnemonic.keychain.bitcoinMainnetKeychain;

            MYCWalletAccount* account = [[MYCWalletAccount alloc] initWithKeychain:[bitcoinKeychain keychainForAccount:0]];

            NSAssert(account, @"Must be a valid account");

            account.label = NSLocalizedString(@"Main Account", @"");
            account.current = YES;

            return [account saveInDatabase:db error:outError];
        }];
    }


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
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.databaseURL.path])
    {
        MYCLog(@"WARNING: MYCWallet is removing Mycelium database from disk.");
    }

    if (_database) [_database close];

    _database = nil;
    NSError* error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.databaseURL error:&error];

    // Do not notify to not break the app.
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

// Loads current active account from database.
- (MYCWalletAccount*) currentAccountFromDatabase:(FMDatabase*)db
{
    return [[MYCWalletAccount loadWithCondition:@"current = 1 LIMIT 1" fromDatabase:db] firstObject];
}

// Loads all accounts from database.
- (NSArray*) accountsFromDatabase:(FMDatabase*)db
{
    return [MYCWalletAccount loadWithCondition:@"ORDER BY accountIndex" fromDatabase:db];
}

// Loads a specific account at index from database.
// If account does not exist, returns nil.
- (MYCWalletAccount*) accountAtIndex:(uint32_t)index fromDatabase:(FMDatabase*)db
{
    return [MYCWalletAccount loadWithPrimaryKey:@(index) fromDatabase:db];
}




#pragma mark - Networking



- (BOOL) isNetworkActive
{
    return self.backend.isActive;
}

- (BOOL) isUpdatingAccounts
{
    return _updatingAccountsTaskCount > 0;
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
        if (date && [date timeIntervalSinceNow] > -3600.0)
        {
            // Updated an hour ago, so should be up to date.
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
                                                if (completion) completion(NO, error);
                                                return;
                                            }

                                            self.currencyConverter.averageRate = btcPrice;
                                            self.currencyConverter.marketName = marketName;
                                            if (date) self.currencyConverter.date = date;
                                            self.currencyConverter.nativeCurrencyCode = nativeCurrencyCode ?: self.currencyConverter.currencyCode;

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
    // TODO: update balance info and unspent outputs.
    if (completion) completion(NO, nil);
}


- (void) notifyNetworkActivity
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateNetworkActivity object:self];
}



@end

