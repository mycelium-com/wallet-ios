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
#import "MYCOutgoingTransaction.h"
#import "MYCTransaction.h"
#import "MYCParentOutput.h"
#import "MYCUnspentOutput.h"
#import "MYCCurrencyFormatter.h"
#import "BTCPriceSourceMycelium.h"

NSString* const MYCWalletFormatterDidUpdateNotification = @"MYCWalletFormatterDidUpdateNotification";
NSString* const MYCWalletCurrencyConverterDidUpdateNotification = @"MYCWalletCurrencyConverterDidUpdateNotification";
NSString* const MYCWalletDidReloadNotification = @"MYCWalletDidReloadNotification";
NSString* const MYCWalletDidUpdateNetworkActivityNotification = @"MYCWalletDidUpdateNetworkActivityNotification";
NSString* const MYCWalletDidUpdateAccountNotification = @"MYCWalletDidUpdateAccountNotification";

const NSUInteger MYCAccountDiscoveryWindow = 10;

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
    NSArray* _currencyFormatters;
    MYCCurrencyFormatter* _primaryCurrencyFormatter;
    MYCCurrencyFormatter* _secondaryCurrencyFormatter;

    MYCUnlockedWallet* _unlockedWallet; // allows nesting calls with the same unlockedWallet.
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
        self.compactDateFormatter = [[NSDateFormatter alloc] init];
        self.compactDateFormatter.dateStyle = NSDateFormatterLongStyle;
        self.compactDateFormatter.timeStyle = NSDateFormatterNoStyle;

        self.compactTimeFormatter = [[NSDateFormatter alloc] init];
        self.compactTimeFormatter.dateStyle = NSDateFormatterNoStyle;
        self.compactTimeFormatter.timeStyle = NSDateFormatterShortStyle;
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
    if (!num) return BTCNumberFormatterUnitBTC;
    return [num unsignedIntegerValue];
}

- (void) setBitcoinUnit:(BTCNumberFormatterUnit)bitcoinUnit
{
    [[NSUserDefaults standardUserDefaults] setObject:@(bitcoinUnit) forKey:@"MYCWalletBitcoinUnit"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.btcFormatter.bitcoinUnit = bitcoinUnit;
    self.btcFormatterNaked.bitcoinUnit = bitcoinUnit;
}

- (BTCNumberFormatter*) btcFormatter
{
    if (!_btcFormatter)
    {
        _btcFormatter = [[BTCNumberFormatter alloc] initWithBitcoinUnit:self.bitcoinUnit symbolStyle:BTCNumberFormatterSymbolStyleCode];
    }
    return _btcFormatter;
}

- (BTCNumberFormatter*) btcFormatterNaked
{
    if (!_btcFormatterNaked)
    {
        _btcFormatterNaked = [[BTCNumberFormatter alloc] initWithBitcoinUnit:self.bitcoinUnit symbolStyle:BTCNumberFormatterSymbolStyleNone];
    }
    return _btcFormatterNaked;
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

        // [[NSLocale currentLocale] displayNameForKey:NSLocaleCurrencySymbol value:@"USD"];
        // Returns "$US" for symbol and "dollar des etats unis" for code.

        _fiatFormatter.currencySymbol = NSLocalizedString(@"USD", @"");
        _fiatFormatter.internationalCurrencySymbol = _fiatFormatter.currencySymbol;
        _fiatFormatter.positivePrefix = @"";
        _fiatFormatter.positiveSuffix = [@"\xE2\x80\xAF" stringByAppendingString:_fiatFormatter.currencySymbol];
        _fiatFormatter.negativeFormat = [_fiatFormatter.positiveFormat stringByReplacingCharactersInRange:[_fiatFormatter.positiveFormat rangeOfString:@"#"] withString:@"-#"];
    }
    return _fiatFormatter;
}

- (NSNumberFormatter*) fiatFormatterNaked
{
    if (!_fiatFormatterNaked)
    {
        // For now we only support USD, but will have to support various currency exchanges later.
        _fiatFormatterNaked = [self.fiatFormatter copy];
        _fiatFormatterNaked.currencySymbol = @"";
        _fiatFormatterNaked.internationalCurrencySymbol = @"";
        _fiatFormatterNaked.positivePrefix = @"";
        _fiatFormatterNaked.positiveSuffix = @"";
        _fiatFormatterNaked.minimumFractionDigits = 0;
        _fiatFormatterNaked.negativeFormat = [_fiatFormatter.positiveFormat stringByReplacingCharactersInRange:[_fiatFormatter.positiveFormat rangeOfString:@"#"] withString:@"-#"];
    }
    return _fiatFormatterNaked;
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
            _currencyConverter.sourceName = @"Bitstamp";
            _currencyConverter.averageRate = [NSDecimalNumber zero];
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

- (MYCWalletPreferredCurrency) preferredCurrency
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"MYCWalletPreferredCurrency"];
}

- (void) setPreferredCurrency:(MYCWalletPreferredCurrency)pc
{
    [[NSUserDefaults standardUserDefaults] setInteger:pc forKey:@"MYCWalletPreferredCurrency"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray*) currencyFormatters {
    if (!_currencyFormatters) {
        _currencyFormatters =  @[
                                 [[MYCCurrencyFormatter alloc] initWithBTCFormatter:
                                  [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBTC symbolStyle:BTCNumberFormatterSymbolStyleSymbol]],
                                 [[MYCCurrencyFormatter alloc] initWithBTCFormatter:
                                  [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitMilliBTC symbolStyle:BTCNumberFormatterSymbolStyleSymbol]],
                                 [[MYCCurrencyFormatter alloc] initWithBTCFormatter:
                                  [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBit symbolStyle:BTCNumberFormatterSymbolStyleSymbol]],
//                                 
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"JPY"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"USD"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"EUR"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"CNY"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"GBP"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"AUD"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"CAD"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"CHF"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"NZD"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"RUB"]],
//                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"UAH"]],
                                 ];
    }
    return _currencyFormatters;
}

- (BTCCurrencyConverter*) persistentCurrencyConverterWithCode:(NSString*)code {
    
    NSDictionary* cachedConverterDict = [[NSUserDefaults standardUserDefaults] objectForKey:[self formatterKeyForCurrencyCode:code]];
    
    BTCCurrencyConverter* currencyConverter = nil;
    
    if (cachedConverterDict) {
        currencyConverter = [[BTCCurrencyConverter alloc] initWithDictionary:cachedConverterDict];
    } else {
        currencyConverter = [[BTCCurrencyConverter alloc] init];
        currencyConverter.currencyCode = code;
    }
    return currencyConverter;
}

- (NSString*) reformatString:(NSString*)amount forCurrency:(NSString*)currencyCode {
    if (!currencyCode) return nil;
    if (!amount) return nil;
    for (MYCCurrencyFormatter* fmt in self.currencyFormatters) {
        if ([fmt.currencyCode isEqual:currencyCode]) {
            return [fmt.fiatReformatter stringFromNumber:[NSDecimalNumber decimalNumberWithString:amount]];
        }
    }
    return nil;
}

- (void) updateCurrencyFormatter:(MYCCurrencyFormatter*)formatter completionHandler:(void(^)(BOOL result, NSError* error))completionHandler {
    if (formatter.isBitcoinFormatter) {
        if (completionHandler) completionHandler(YES, nil);
        return;
    }
    
    BTCPriceSourceMycelium* source = [[BTCPriceSourceMycelium alloc] init];
    [source loadPriceForCurrency:formatter.currencyCode completionHandler:^(BTCPriceSourceResult *result, NSError *error) {
        
        if (!result) {
            if (completionHandler) completionHandler(NO, error);
            return;
        }
        
        formatter.currencyConverter.averageRate = result.averageRate;
        formatter.currencyConverter.date = result.date;
        formatter.currencyConverter.sourceName = source.name;
        
        [self saveCurrencyFormatter:formatter];
        if (completionHandler) completionHandler(YES, nil);
        [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletCurrencyConverterDidUpdateNotification object:formatter];
    }];
}

- (void) saveCurrencyFormatter:(MYCCurrencyFormatter*)formatter {
    if (formatter.isFiatFormatter) {
        NSDictionary* dict = formatter.currencyConverter.dictionary;
        if (dict) {
            [[NSUserDefaults standardUserDefaults] setObject:dict forKey:[self formatterKeyForCurrencyCode:formatter.currencyCode]];
        }
    }
}

- (NSString*) formatterKeyForCurrencyCode:(NSString*)code {
    return [NSString stringWithFormat:@"MYCCurrencyFormatter%@", code];
}

- (void) selectPrimaryCurrencyFormatter:(MYCCurrencyFormatter*)formatter {
    
    if ([formatter.currencyCode isEqual:_primaryCurrencyFormatter.currencyCode]) {
        return;
    }
    
    if (formatter.isFiatFormatter) {
        _secondaryCurrencyFormatter = self.btcCurrencyFormatter;
    }
    if (formatter.isBitcoinFormatter) {
        _secondaryCurrencyFormatter = self.fiatCurrencyFormatter;
    }
    
    _primaryCurrencyFormatter = formatter;
    
    [self saveCurrencyFormatterSelection];
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletCurrencyConverterDidUpdateNotification object:formatter];
}

- (void) saveCurrencyFormatterSelection {
    [[NSUserDefaults standardUserDefaults] setObject:_primaryCurrencyFormatter.dictionary ?: @{} forKey:@"MYCWalletPrimaryCurrencyFormatter"];
    [[NSUserDefaults standardUserDefaults] setObject:_secondaryCurrencyFormatter.dictionary ?: @{} forKey:@"MYCWalletSecondaryCurrencyFormatter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) loadCurrencyFormatterSelection {
    NSDictionary* primaryDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletPrimaryCurrencyFormatterV2"];
    NSDictionary* secondaryDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletSecondaryCurrencyFormatterV2"];
    
    _primaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithDictionary:primaryDict];
    _secondaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithDictionary:secondaryDict];
    
    if (!_primaryCurrencyFormatter || !_secondaryCurrencyFormatter) {
        
        self.currencyConverter = [[BTCCurrencyConverter alloc] init];
        self.currencyConverter.currencyCode = [self defaultFiatCurrency];
        
        _primaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:self.currencyConverter];
        _secondaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithBTCFormatter:[self defaultBitcoinFormatter]];
    }
}

- (NSString*) defaultFiatCurrency {
    return @"USD";
}

- (BTCNumberFormatter*) defaultBitcoinFormatter {
    return [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBTC symbolStyle:BTCNumberFormatterSymbolStyleSymbol];
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
    // If already within a context of unlocked wallet, reuse it.
    if (_unlockedWallet)
    {
        block(_unlockedWallet);
        return;
    }

    _unlockedWallet = [[MYCUnlockedWallet alloc] init];

    _unlockedWallet.wallet = self;
    _unlockedWallet.reason = reason;

    block(_unlockedWallet);

    [_unlockedWallet clear];
    _unlockedWallet = nil;
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

    // Register model migrations

    [MYCDatabaseMigrations registerMigrations:database];


    // Create a default account

    [database registerMigration:@"Create Main Account" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {

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
            return [self openDatabaseOrCreateWithMnemonic:mnemonic];
        }
        else
        {
            [NSException raise:NSInternalInconsistencyException format:@"Give up because can not delete database file (%@)", error];
        }
    }

    // Database file flags

    {
        // Note: SQLite DB file encryption is provided by global App ID settings (complete file protection).
        // The secret is always protected since it's stored in Keychain with setting "this device only, when unlocked only".

        // Prevent database file from iCloud backup
        if (![database.URL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error])
        {
            NSLog(@"WARNING: Can not exclude database file from backup (%@)", error);
            //[NSException raise:NSInternalInconsistencyException format:@"Can not exclude database file from backup (%@)", error];
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

- (void) asyncInDatabase:(id(^)(FMDatabase *db, NSError** dberrorOut))dbBlock completion:(void(^)(id result, NSError* dberror))completion
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self inDatabase:^(FMDatabase *db) {

            NSError* dberror = nil;
            id result = dbBlock ? dbBlock(db, &dberror) : @YES;

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(result, dberror);
            });
        }];
    });
}

- (void) asyncInTransaction:(id(^)(FMDatabase *db, BOOL *rollback, NSError** dberrorOut))block completion:(void(^)(id result, NSError* dberror))completion
{
    NSParameterAssert(block);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self inTransaction:^(FMDatabase *db, BOOL *rollback) {

            NSError* dberror = nil;
            id result = block ? block(db, rollback, &dberror) : @YES;

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(result, dberror);
            });
        }];
    });
}


//- (void) inTransaction:(BOOL(^)(FMDatabase *db, BOOL *rollback, NSError** dberrorOut))block completion:(void(^)(BOOL result, NSError* dberror))completion;



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
                                            self.currencyConverter.sourceName = marketName;
                                            if (date) self.currencyConverter.date = date;
                                            self.currencyConverter.nativeCurrencyCode = nativeCurrencyCode ?: self.currencyConverter.currencyCode;

                                            [self saveCurrencyConverter];

                                            if (completion) completion(YES, nil);

                                            [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletCurrencyConverterDidUpdateNotification object:self];

                                            [self notifyNetworkActivity];
                                        }];

    [self notifyNetworkActivity];

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

    // Broadcast pending txs if needed.
    [self broadcastOutgoingTransactions:^(BOOL success, NSError *error) { }];

    MYCUpdateAccountOperation* op = [[MYCUpdateAccountOperation alloc] initWithAccount:account wallet:self];
    [_accountUpdateOperations addObject:op];

    [op update:^(BOOL success, NSError *error) {

        NSAssert([NSThread mainThread], @"Must be on main thread");

        [_accountUpdateOperations removeObjectIdenticalTo:op];

        [self notifyNetworkActivity];

        if (success)
        {
            __block NSError* dberror = nil;
            [self inDatabase:^(FMDatabase *db) {
                // Make sure we use the latest data and update the sync date.
                [account reloadFromDatabase:db];
                account.syncDate = [NSDate date];
                if (![account saveInDatabase:db error:&dberror])
                {
                    dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error when updating account sync date."}];
                    MYCError(@"MYCWallet: failed to save account with bumped syncDate in database: %@", dberror);
                }
            }];

            if (dberror)
            {
                if (completion) completion(NO, dberror);
                return;
            }
        }

        if (completion) completion(success, error);

        [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:account];
    }];

    [self notifyNetworkActivity];
}


- (void) broadcastTransaction:(BTCTransaction*)tx fromAccount:(MYCWalletAccount*)account completion:(void(^)(BOOL success, BOOL queued, NSError *error))completion
{
    if (!tx)
    {
        if (completion) completion(NO, NO, nil);
        return;
    }

    // First, make sure all previous transactions are broadcasted.
    // If broadcasting previous transactions fails, allow adding current one to the queue
    // (so you can make multiple payments before all of them are sent to the network).
    [self broadcastOutgoingTransactions:^(BOOL success, NSError *error) {
        if (!success)
        {
            MYCError(@"Failed to broadcast previous pending transactions. Adding new tx %@ to queue. Error: %@", tx.transactionID, error);
            [self asyncInDatabase:^id(FMDatabase *db, NSError *__autoreleasing *dberrorOut) {

                MYCOutgoingTransaction* pendingTx = [[MYCOutgoingTransaction alloc] init];
                pendingTx.transaction = tx;
                return [pendingTx saveInDatabase:db error:dberrorOut] ? @YES : nil;

            } completion:^(id result, NSError *dberror) {

                if (result)
                {
                    [self markTransactionAsSpent:tx account:account error:NULL];
                }

                if (completion) completion(NO, !!result, error);
                return;
            }];

            return;
        }

        // All txs broadcasted (or none are queued), try to broadcast our transaction.
        [self.backend broadcastTransaction:tx completion:^(MYCBroadcastStatus status, NSError *error) {

            // Bad transaction rejected. Return error and do nothing else.
            if (status == MYCBroadcastStatusBadTransaction)
            {
                MYCError(@"Cannot broadcast transaction: %@. Error: %@. Raw hex: %@", tx.transactionID, error, BTCHexFromData(tx.data));
                if (completion) completion(NO, NO, error);
                return;
            }

            // Good transaction accepted. Update unspent outputs and return.
            if (status == MYCBroadcastStatusSuccess)
            {
                if (account) [self markTransactionAsSpent:tx account:account error:NULL];
                if (completion) completion(YES, NO, nil);
                return;
            }

            // Failed to deliver the transaction.
            MYCError(@"Connection error while broadcasting transaction %@. Adding it to outgoing queue. Error: %@", tx.transactionID, error);

            __block NSError* dberror = nil;
            [self inDatabase:^(FMDatabase *db) {
                MYCOutgoingTransaction* pendingTx = [[MYCOutgoingTransaction alloc] init];
                pendingTx.transaction = tx;
                if (![pendingTx saveInDatabase:db error:&dberror])
                {
                    dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error while saving MYCOutgoingTransaction"}];
                }
            }];

            if (account) [self markTransactionAsSpent:tx account:account error:NULL];

            if (completion) completion(NO, !dberror, dberror ?: error);
        }];

    }];
}

// Recursively cleans up broadcast queue.
- (void) broadcastOutgoingTransactions:(void(^)(BOOL success, NSError*error))completion
{
    [self asyncInDatabase:^id(FMDatabase *db, NSError *__autoreleasing *dberrorOut) {

        MYCOutgoingTransaction* pendingTx = [[MYCOutgoingTransaction loadWithCondition:@"1 ORDER BY id LIMIT 1" fromDatabase:db] firstObject];
        return pendingTx;

    } completion:^(MYCOutgoingTransaction* pendingTx, NSError *dberror) {

        // No pending tx, nothing to broadcast.
        if (!pendingTx)
        {
            if (completion) completion(YES, nil);
            return;
        }

        [self.backend broadcastTransaction:pendingTx.transaction completion:^(MYCBroadcastStatus status, NSError *error) {

            // If failed to broadcast, fail the entire process of broadcasting.
            if (status == MYCBroadcastStatusNetworkFailure)
            {
                MYCError(@"Failed to broadcast pending transaction %@. Error: %@", pendingTx.transactionID, error);
                if (completion) completion(NO, error);
                return;
            }

            if (status == MYCBroadcastStatusBadTransaction)
            {
                MYCError(@"Outgoing transaction %@ rejected, removing from queue.", pendingTx.transactionID);
            }
            else
            {
                MYCError(@"Outgoing transaction %@ successfully broadcasted, removing from queue.", pendingTx.transactionID);
            }

            // Transaction is either rejected (invalid, doublespent) or accepted and broadcasted.
            // If tx is rejected, coins spent in this tx will become available again after account sync.
            [self inDatabase:^(FMDatabase *db) {
                [pendingTx deleteFromDatabase:db error:NULL];
            }];

            [self broadcastOutgoingTransactions:completion];
        }];
    }];
}

// Marks transaction as spent so we don't accidentally double-spend it.
- (BOOL) markTransactionAsSpent:(BTCTransaction*)tx account:(MYCWalletAccount*)account error:(NSError**)errorOut
{
    if (!tx) return NO;

    if (!account) return NO;

    __block BOOL succeeded = YES;
    [self inTransaction:^(FMDatabase *db, BOOL *rollback) {

        // Remove inputs from unspent, marking them as spent

        for (BTCTransactionInput* txin in tx.inputs)
        {
            MYCUnspentOutput* mout = [MYCUnspentOutput loadOutputForAccount:account.accountIndex hash:txin.previousHash index:txin.previousIndex database:db];
            if (mout)
            {
                NSError* dberror = nil;
                if (![mout deleteFromDatabase:db error:&dberror])
                {
                    MYCError(@"Cannot remove unspent output linking to txin of the new transaction (%@:%@): %@", txin.previousTransactionID, @(txin.previousIndex), dberror);
                    if (errorOut) *errorOut = dberror;
                    succeeded = NO;
                    return;
                }
                else
                {
                    MYCLog(@"MYCWallet: removed unspent output (now spent): %@:%@", BTCIDFromHash(mout.transactionOutput.transactionHash), @(mout.transactionOutput.index));
                }
            }
        }

        // See if any of the outputs are for ourselves and store them as unspent

        for (NSInteger i = 0; i < tx.outputs.count; i++)
        {
            BTCTransactionOutput* txout = tx.outputs[i];

            MYCUnspentOutput* mout = [[MYCUnspentOutput alloc] init];
            mout.blockHeight = -1;
            mout.transactionOutput = txout;
            mout.accountIndex = account.accountIndex;

            // Find which address is used on this output.
            NSInteger change = 0;
            NSInteger keyIndex = 0;
            if ([account matchesScriptData:txout.script.data change:&change keyIndex:&keyIndex])
            {
                mout.change = change;
                mout.keyIndex = keyIndex;
                NSError* dberror = nil;
                if (![mout insertInDatabase:db error:&dberror])
                {
                    dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error when inserting new unspent output"}];
                    if (errorOut) *errorOut = dberror;
                    succeeded = NO;

                    MYCError(@"MYCWallet: failed to save fresh unspent output %@ for account %d in database: %@", txout, (int)account.accountIndex, dberror);
                    return;
                }
                else
                {
                    MYCLog(@"MYCWallet: added new unspent output (from new transaction): %@:%@", BTCIDFromHash(txout.transactionHash), @(txout.index));
                }
            }
        }

        // Store transaction locally, so we have it in our history and don't
        // need to fetch it in a minute
        MYCTransaction* mtx = [[MYCTransaction alloc] init];

        mtx.transactionHash = tx.transactionHash;
        mtx.data            = tx.data;
        mtx.blockHeight     = -1;
        mtx.date            = nil;
        mtx.accountIndex    = account.accountIndex;

        NSError* dberror = nil;
        if (![mtx insertInDatabase:db error:&dberror])
        {
            dberror = dberror ?: [NSError errorWithDomain:MYCErrorDomain code:666 userInfo:@{NSLocalizedDescriptionKey: @"Unknown DB error"}];
            succeeded = NO;
            if (errorOut) *errorOut = dberror;
            
            MYCError(@"MYCWallet: failed to save transaction %@ for account %d in database: %@", tx.transactionID, (int)account.accountIndex, dberror);
            return;
        }
        else
        {
            MYCLog(@"MYCUpdateAccountOperation: saved new transaction: %@", tx.transactionID);
        }
    }];

    if (!succeeded)
    {
        return NO;
    }

    // Calculate local balance cache. It has changed because we have done some spending.
    [self updateAccount:account force:YES completion:^(BOOL success, NSError *error) {
        if (success)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:account];
        }
    }];

//    MYCUpdateAccountOperation* op = [[MYCUpdateAccountOperation alloc] initWithAccount:account wallet:self];
//    [_accountUpdateOperations addObject:op];
//    [op updateLocalBalance:^(BOOL success, NSError *error) {
//        [_accountUpdateOperations removeObjectIdenticalTo:op];
//
//        if (success)
//        {
//            [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:account];
//        }
//    }];

    return YES;
}

// Update all active accounts.
- (void) updateActiveAccounts:(void(^)(BOOL success, NSError *error))completion
{
    [self asyncInDatabase:^id(FMDatabase *db, NSError *__autoreleasing *dberrorOut) {
        return [MYCWalletAccount loadWithCondition:@"archived = 0" fromDatabase:db];
    } completion:^(NSArray* accs, NSError *dberror) {
        if (!accs)
        {
            if (completion) completion(NO, dberror);
            return;
        }
        [self recursivelyUpdateAccounts:accs force:NO completion:completion];
    }];
}

// NSArray* remainingAccounts = [self.activeAccounts arrayByAddingObjectsFromArray:self.archivedAccounts];
- (void) recursivelyUpdateAccounts:(NSArray*)accs force:(BOOL)force completion:(void(^)(BOOL success, NSError *error))completion
{
    if (accs.count == 0)
    {
        if (completion) completion(YES, nil);
        return;
    }

    MYCWalletAccount* acc = [accs firstObject];

    // Make requests to synchronize active accounts.
    [self updateAccount:acc force:force completion:^(BOOL success, NSError *error) {
        if (!success && error)
        {
            if (completion) completion(success, error);
            return;
        }
        [self recursivelyUpdateAccounts:[accs subarrayWithRange:NSMakeRange(1, accs.count - 1)] force:force completion:completion];
    }];
}


// Discover accounts with a sliding window. Since accounts' keychains are derived in a hardened mode,
// we need a root keychain with private key to derive accounts' addresses.
// Newly discovered accounts are created automatically with default names.
- (void) discoverAccounts:(BTCKeychain*)rootKeychain completion:(void(^)(BOOL success, NSError *error))completion
{
#if 0
#warning DEBUG: disabled discovery of accounts
    if (completion) completion(YES, nil);
    return;
#endif
    
    __block NSInteger nextAccountIndex = 0;
    [self inDatabase:^(FMDatabase *db) {
        MYCWalletAccount* acc = [[MYCWalletAccount loadWithCondition:@"1 ORDER BY accountIndex DESC LIMIT 1" fromDatabase:db] firstObject];
        nextAccountIndex = acc ? (acc.accountIndex + 1) : 0;
    }];

    // Original will be cleared and this one will be used in async fashion.
    // This will be cleaned when discovery is over.
    rootKeychain = [rootKeychain copy];

    // Recursively discover accounts
    [self discoverAccounts:rootKeychain accountIndex:nextAccountIndex window:MYCAccountDiscoveryWindow completion:completion];
}

// Tries to discover while window is > 0. Resets window to MYCAccountDiscoveryWindow when something is discovered and creates intermediate accounts.
- (void) discoverAccounts:(BTCKeychain*)rootKeychain accountIndex:(NSInteger)accountIndex window:(NSInteger)window completion:(void(^)(BOOL success, NSError *error))completion
{
    if (window == 0)
    {
        MYCLog(@"MYCWallet: Finished discovering accounts.");
        [rootKeychain clear];
        if (completion) completion(YES, nil);
        return;
    }

    BTCKeychain* accKeychain = [[rootKeychain keychainForAccount:(uint32_t)accountIndex] publicKeychain];

    // Scan 20 external address and 2 internal ones.
    NSMutableArray* addrs = [NSMutableArray array];
    for (uint32_t j = 0; j < 2; j++) {
        BTCAddress* addr = [self addressForAddress:[BTCPublicKeyAddress addressWithData:BTCHash160([accKeychain externalKeyAtIndex:j].publicKey)]];
        [addrs addObject:addr];
    }
    for (uint32_t j = 0; j < 2; j++) {
        BTCAddress* addr = [self addressForAddress:[BTCPublicKeyAddress addressWithData:BTCHash160([accKeychain changeKeyAtIndex:j].publicKey)]];
        [addrs addObject:addr];
    }

    MYCLog(@"MYCWallet: Discovering account %@ (%@ accounts left; addresses: %@, acc keychain: %@)...",
           @(accountIndex), @(window - 1), [addrs valueForKey:@"base58String"], accKeychain.extendedPublicKey);

    [self.backend loadTransactionsForAddresses:addrs limit:2 completion:^(NSArray *txs, NSInteger height, NSError *error) {

        if (txs && txs.count > 0)
        {
            MYCLog(@"MYCWallet: Discovered account: %@", @(accountIndex));
            __block BOOL dbresult = NO;
            __block NSError* dberror = nil;
            [self inDatabase:^(FMDatabase *db) {

                // Figure which is the latest existing account and create all intermediate ones
                MYCWalletAccount* lastAccount = [[MYCWalletAccount loadWithCondition:@"1 ORDER BY accountIndex DESC LIMIT 1" fromDatabase:db] firstObject];
                NSInteger nextAccountIndex = lastAccount ? (lastAccount.accountIndex + 1) : 0;

                // Save this and all preceding empty accounts.
                for (NSInteger i = nextAccountIndex; i <= accountIndex; i++)
                {
                    MYCLog(@"MYCWallet: Saving account %@", @(i));
                    BTCKeychain* kc = [[rootKeychain keychainForAccount:(uint32_t)i] publicKeychain];
                    MYCWalletAccount* acc = [[MYCWalletAccount alloc] initWithKeychain:kc];
                    if (![acc saveInDatabase:db error:&dberror])
                    {
                        MYCLog(@"MYCWallet: Failed to save account %@. Error: %@", @(i), dberror);
                        dbresult = NO;
                        return;
                    }
                }
                dbresult = YES;
            }];

            if (!dbresult)
            {
                [rootKeychain clear];
                if (completion) completion(NO, dberror);
                return;
            }

            // Continue discovering with a big window
            [self discoverAccounts:rootKeychain accountIndex:accountIndex + 1 window:MYCAccountDiscoveryWindow completion:completion];
        }
        else if (txs && txs.count == 0)
        {
            MYCLog(@"MYCWallet: no transactions on addresses for account %@: %@", @(accountIndex), [addrs valueForKey:@"base58String"]);
            // Continue discovering
            [self discoverAccounts:rootKeychain accountIndex:accountIndex + 1 window:window - 1 completion:completion];
        }
        else
        {
            // Failed to load transactions
            MYCLog(@"MYCWallet: Failed to load transactions for account %@. Error: %@", @(accountIndex), error);
            [rootKeychain clear];
            if (completion) completion(NO, error);
        }
    }];
}

// Returns YES if this new account if within a window of empty accounts.
- (BOOL) canAddAccount
{
    // check how many accounts are empty and return NO if outside the search window
    __block BOOL result = NO;
    [self inDatabase:^(FMDatabase *db) {
        NSArray* accs = [MYCWalletAccount loadWithCondition:[NSString stringWithFormat:@"1 ORDER BY accountIndex DESC LIMIT %@", @(MYCAccountDiscoveryWindow)] fromDatabase:db];

        if (accs.count < MYCAccountDiscoveryWindow)
        {
            result = YES;
            return;
        }

        for (MYCWalletAccount* acc in accs)
        {
            if (acc.spendableAmount > 0)
            {
                result = YES;
                return;
            }
        }
    }];

    return result;
}


- (void) notifyNetworkActivity
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateNetworkActivityNotification object:self];
}



@end

