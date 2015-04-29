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
#import "MYCWalletBackup.h"
#import "MYCDatabase.h"
#import "MYCBackend.h"
#import "MYCDatabaseMigrations.h"
#import "MYCUpdateAccountOperation.h"
#import "MYCOutgoingTransaction.h"
#import "MYCTransaction.h"
#import "MYCTransactionDetails.h"
#import "MYCParentOutput.h"
#import "MYCUnspentOutput.h"
#import "MYCCurrencyFormatter.h"
#import "BTCPriceSourceMycelium.h"
#import "MYCCloudKit.h"
#include <pthread.h>
#include <LocalAuthentication/LocalAuthentication.h>

NSString* const MYCWalletCurrencyDidUpdateNotification = @"MYCWalletCurrencyDidUpdateNotification";
NSString* const MYCWalletDidReloadNotification = @"MYCWalletDidReloadNotification";
NSString* const MYCWalletDidUpdateNetworkActivityNotification = @"MYCWalletDidUpdateNetworkActivityNotification";
NSString* const MYCWalletDidUpdateAccountNotification = @"MYCWalletDidUpdateAccountNotification";

const NSUInteger MYCAccountDiscoveryWindow = 10;

@interface MYCWallet ()
@property(nonatomic) MYCDatabase* database;
@property(nonatomic) NSURL* databaseURL;
@property(nonatomic) NSArray* currencyFormatters;
@property(nonatomic) MYCCurrencyFormatter* primaryCurrencyFormatter;
@property(nonatomic) MYCCurrencyFormatter* secondaryCurrencyFormatter;
@property(nonatomic) NSMutableString* log;
// Returns current database configuration.
// Returns nil if database is not created yet.
- (MYCDatabase*) database;

@end

@implementation MYCWallet {
    int _updatingExchangeRate;
    NSMutableArray* _accountUpdateOperations;
    BOOL _needsBackup;
    BOOL _backingUp;
    NSDate* _lastBackupDate;
    NSError* _lastBackupError;
    UIBackgroundTaskIdentifier _backgroundTaskIdentifier;
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
        [self loadCurrencyFormatterSelection];
        
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
            } reason:NSLocalizedString(@"Authorize change of network mode", @"")];
        }
    }
}

- (BTCNetwork*) network {
    if (self.isTestnet) {
        return [BTCNetwork testnet];
    }
    return [BTCNetwork mainnet];
}

- (void) setNetwork:(BTCNetwork *)network {
    self.testnet = network.isTestnet;
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

- (BOOL) walletSetupInProgress
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"MYCWalletSetupInProgress"];
}

- (void) setWalletSetupInProgress:(BOOL)flag
{
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"MYCWalletSetupInProgress"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (BOOL) isMigratedToTouchID
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"MYCDidMigrateToTouchID"];
}

- (void) setMigratedToTouchID:(BOOL)migrated
{
    [[NSUserDefaults standardUserDefaults] setBool:migrated forKey:@"MYCDidMigrateToTouchID"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate*) dateLastAskedAboutMigratingToTouchID {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCDateLastAskedAboutMigratingToTouchID"] ?: [NSDate dateWithTimeIntervalSince1970:0];
}

- (void) setDateLastAskedAboutMigratingToTouchID:(NSDate *)dateLastAskedAboutMigratingToTouchID {
    [[NSUserDefaults standardUserDefaults] setObject:dateLastAskedAboutMigratingToTouchID ?: [NSDate dateWithTimeIntervalSince1970:0]
                                              forKey:@"MYCDateLastAskedAboutMigratingToTouchID"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate*) dateLastAskedToVerifyBackupAccess {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCDateLastAskedToVerifyBackupAccess"];
}

- (void) setDateLastAskedToVerifyBackupAccess:(NSDate *)date {
    [[NSUserDefaults standardUserDefaults] setObject:date ?: [NSDate dateWithTimeIntervalSince1970:0]
                                              forKey:@"MYCDateLastAskedToVerifyBackupAccess"];
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
    return self.btcCurrencyFormatter.btcFormatter;
}

- (BTCNumberFormatter*) btcFormatterNaked
{
    return (id)self.btcCurrencyFormatter.nakedFormatter;
}

- (NSNumberFormatter*) fiatFormatter
{
    return self.fiatCurrencyFormatter;
}

- (NSNumberFormatter*) fiatFormatterNaked
{
    return self.fiatCurrencyFormatter.nakedFormatter;
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

- (MYCCurrencyFormatter*) fiatCurrencyFormatter {
    return self.primaryCurrencyFormatter.isFiatFormatter ? self.primaryCurrencyFormatter : self.secondaryCurrencyFormatter;
}

- (MYCCurrencyFormatter*) btcCurrencyFormatter {
    return self.primaryCurrencyFormatter.isBitcoinFormatter ? self.primaryCurrencyFormatter : self.secondaryCurrencyFormatter;
}

- (NSArray*) currencyFormatters {
    if (!_currencyFormatters) {
        _currencyFormatters =  @[
                                 [[MYCCurrencyFormatter alloc] initWithBTCFormatter:
                                  [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBTC symbolStyle:BTCNumberFormatterSymbolStyleCode]],
                                 [[MYCCurrencyFormatter alloc] initWithBTCFormatter:
                                  [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitMilliBTC symbolStyle:BTCNumberFormatterSymbolStyleCode]],
                                 [[MYCCurrencyFormatter alloc] initWithBTCFormatter:
                                  [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBit symbolStyle:BTCNumberFormatterSymbolStyleCode]],
                                 
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"USD"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"EUR"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"GBP"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"CAD"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"AUD"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"NZD"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"JPY"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"CNY"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"CHF"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"RUB"]],
                                 [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:[self persistentCurrencyConverterWithCode:@"UAH"]],
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

- (MYCCurrencyFormatter*) currencyFormatterForCode:(NSString*)code {
    if (!code) return nil;
    for (MYCCurrencyFormatter* fmt in self.currencyFormatters) {
        if ([fmt.currencyCode isEqual:code]) {
            return fmt;
        }
    }
    return nil;
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
        [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletCurrencyDidUpdateNotification object:formatter];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletCurrencyDidUpdateNotification object:formatter];
}

- (void) saveCurrencyFormatterSelection {
    [[NSUserDefaults standardUserDefaults] setObject:_primaryCurrencyFormatter.dictionary ?: @{} forKey:@"MYCWalletPrimaryCurrencyFormatter"];
    [[NSUserDefaults standardUserDefaults] setObject:_secondaryCurrencyFormatter.dictionary ?: @{} forKey:@"MYCWalletSecondaryCurrencyFormatter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) loadCurrencyFormatterSelection {
    NSDictionary* primaryDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletPrimaryCurrencyFormatter"];
    NSDictionary* secondaryDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletSecondaryCurrencyFormatter"];
    
    _primaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithDictionary:primaryDict];
    _secondaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithDictionary:secondaryDict];
    
    if (!_primaryCurrencyFormatter || !_secondaryCurrencyFormatter) {
        
        BTCCurrencyConverter* converter = [[BTCCurrencyConverter alloc] init];
        converter.currencyCode = [self defaultFiatCurrency];
        
        _primaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithCurrencyConverter:converter];
        _secondaryCurrencyFormatter = [[MYCCurrencyFormatter alloc] initWithBTCFormatter:[self defaultBitcoinFormatter]];
    }
}

- (BTCCurrencyConverter*) currencyConverter {
    return self.fiatCurrencyFormatter.currencyConverter;
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
    if ([self walletSetupInProgress]) return NO;
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



- (BOOL) isTouchIDEnabled
{
    return ([LAContext class] &&
            [[LAContext new] canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:NULL]);
}

- (BOOL) isDevicePasscodeEnabled
{
    if (![LAContext class]) return NO; // LAContext is iOS8+, but we only target iOS8 anyway
    NSError* error = nil;
    if ([[LAContext new] canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        return YES;
    }
    if (error && error.code == LAErrorPasscodeNotSet) {
        return NO;
    }
    return [MYCUnlockedWallet isPasscodeSet];
}

// Returns YES if the keychain data is stored correctly.
- (BOOL) verifySeedIntegrity {
    __block BOOL result = NO;
    [self unlockWallet:^(MYCUnlockedWallet *uw) {

        result = [uw readMnemonic] ? YES : NO;

        if (!result) {
            MYCError(@"MYCWallet verifySeedIntegrity: seed cannot be read: %@", uw.error);
        }

        // Note: normally this prompt should never be triggered, only on 1.1 build for those who have migrated to TouchID already by installing from scratch.
    } reason:NSLocalizedString(@"Verifying wallet integrity.", @"")];

    return result;
}

- (void) makeFileBasedSeedIfNeeded:(void(^)(BOOL result, NSError* error))completionBlock {
    if (![UIApplication sharedApplication].isProtectedDataAvailable) {
        completionBlock(NO, [NSError errorWithDomain:MYCErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot make another copy of master seed while device is locked", @"")}]);
        return;
    }
    if ([[MYCUnlockedWallet alloc] init].fileBasedMnemonicIsStored) {
        // already stored, nothing to do here
        completionBlock(YES, nil);
        return;
    }

    [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *uw) {
        BTCMnemonic* mnemonic = uw.mnemonic;
        if (!mnemonic) {
            completionBlock(NO, uw.error);
            return;
        }

        if (![uw makeFileBasedMnemonic:mnemonic]) {
            completionBlock(NO, uw.error);
            return;
        }

        completionBlock(YES, nil);
    } reason:NSLocalizedString(@"Making a file-based copy of the wallet seed", @"")];

}

- (void) migrateToTouchID:(void(^)(BOOL result, NSError* error))completionBlock {
    if (self.isMigratedToTouchID) {
        MYCError(@"MYCWallet migrateToTouchID: Already migrated.");
        completionBlock(NO, nil);
        return;
    }
    if (![self isDevicePasscodeEnabled]) {
        MYCError(@"MYCWallet migrateToTouchID: Seems like device passcode is not set, not migrating.");
        completionBlock(NO, nil);
        return;
    }

    if (!self.isBackedUp) {
        MYCError(@"MYCWallet migrateToTouchID: Not backed up: not migrating.");
        completionBlock(NO, nil);
        return;
    }

    MYCLog(@"MYCWallet: migrating mnemonic to a touchid/passcode protected item");

    [self unlockWallet:^(MYCUnlockedWallet *unlockedWallet) {

        BTCMnemonic* mnemonic = unlockedWallet.mnemonic;
        NSString* words = [mnemonic.words componentsJoinedByString:@" "];
        if (!mnemonic) {
            MYCLog(@"MYCWallet: not migrating mnemonic to a touchid/passcode: can't read the mnemonic (error: %@)", unlockedWallet.error);
            completionBlock(NO, unlockedWallet.error);
            return;
        }

        unlockedWallet.mnemonic = mnemonic;
        
        if (unlockedWallet.error) {
            MYCLog(@"MYCWallet: failed to set mnemonic to a touchid/passcode (error: %@)", unlockedWallet.error);
            NSError* error = [NSError errorWithDomain:MYCErrorDomain
                                        code:-666
                                    userInfo:@{NSLocalizedDescriptionKey:
                                                   [NSString stringWithFormat:NSLocalizedString(@"Upgrading security failed. PLEASE WRITE DOWN YOUR BACKUP SEED: %@\nError: %@", @""), words, unlockedWallet.error]}];

            completionBlock(NO, error);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlockWallet:^(MYCUnlockedWallet *uw2) {

                BTCMnemonic* mnemonic2 = uw2.mnemonic;
                NSString* words2 = [mnemonic2.words componentsJoinedByString:@" "];
                if (!mnemonic2 || ![words2 isEqual:words]) {
                    NSError* error = [NSError errorWithDomain:MYCErrorDomain
                                                code:-666
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                           [NSString stringWithFormat:NSLocalizedString(@"Verification failed. PLEASE WRITE DOWN YOUR BACKUP SEED: %@", @""), words]}];
                    completionBlock(NO, error);
                    return;
                }

                uw2.probeItem = YES;
                self.migratedToTouchID = YES;
                completionBlock(YES, nil);

            } reason:NSLocalizedString(@"Verifying that migration did succeed.", @"")];
        });
    } reason:NSLocalizedString(@"Authenticate security upgrade.", @"")];
}

- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason
{
    MYCUnlockedWallet* unlockedWallet = [[MYCUnlockedWallet alloc] init];

    unlockedWallet.wallet = self;
    unlockedWallet.reason = reason;

    block(unlockedWallet);

    [unlockedWallet clear];
    unlockedWallet = nil;
}


- (void) bestEffortAuthenticateWithTouchID:(void(^)(MYCUnlockedWallet* uw, BOOL authenticated))block reason:(NSString*)reason {

    LAContext *context = [[LAContext alloc] init];

    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:NULL]) {
        [self unlockWallet:^(MYCUnlockedWallet *uw) {
            block(uw, NO);
        } reason:reason];
        return;
    }

    // Only for a few v1.1 users who installed from scratch.
    if (self.isMigratedToTouchID) {
        [self unlockWallet:^(MYCUnlockedWallet *uw) {
            block(uw, NO);
        } reason:reason];
        return;
    }

    context.localizedFallbackTitle = @""; // so the app-specific password option is not displayed.

    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:reason
                      reply:^(BOOL success, NSError *authenticationError) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              if (success) {
                                  [self unlockWallet:^(MYCUnlockedWallet *uw) {
                                      block(uw, YES);
                                  } reason:reason];
                              } else {
                                  block(nil, NO);
                              }
                          });
                      }];
}







// Backup Routines

- (NSString*) backupWalletID {
    return [BTCEncryptedBackup walletIDWithAuthenticationKey:self.backupAuthenticationKey.publicKey];
}

- (BTCKey*) backupAuthenticationKey {
    return [BTCEncryptedBackup authenticationKeyWithBackupKey:self.backupKey];
}

- (NSData*) backupData {
    // Load previous backup if possible or create a new one.
    MYCWalletBackup* bak = nil;
    NSData* storedData = [self storedBackupData];
    if (storedData) {
        bak = [[MYCWalletBackup alloc] initWithData:storedData backupKey:self.backupKey];
        if (!bak) {
            MYCError(@"MYCWallet: Cannot initialize stored backup data. Making one from scratch.");
            bak = [[MYCWalletBackup alloc] init];
        }
    } else {
        bak = [[MYCWalletBackup alloc] init];
    }

    bak.network = self.network;
    bak.currencyFormatter = self.primaryCurrencyFormatter;

    [self inDatabase:^(FMDatabase *db) {
        [bak setAccounts:[MYCWalletAccount loadAccountsFromDatabase:db]];
        [bak setTransactionDetails:[MYCTransactionDetails loadAllFromDatabase:db]];
    }];

    NSData* result = [bak dataWithBackupKey:self.backupKey]; // this sets required values if necessary.

    MYCLog(@"MYCWallet Automatic Backup: %@", bak.dictionary);
    return result;
}

- (void) applyWalletBackup:(MYCWalletBackup*)backup {

    MYC_ASSERT_MAIN_THREAD;

    // 1. Currency converter.
    MYCCurrencyFormatter* fmt = backup.currencyFormatter;
    if (fmt) {
        MYCLog(@"MYCWallet: setting currency formatter to: %@", fmt.dictionary);
        [self selectPrimaryCurrencyFormatter:fmt];
    } else {
        MYCError(@"MYCWallet: cannot restore currency formatter from backup: %@", backup.dictionary[@"currency"]);
    }

    __block BTCKeychain* rootKeychain = nil;
    [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *uw) {
        rootKeychain = [uw.keychain copy]; // so it's not cleared outside unlockWallet block.
    } reason:NSLocalizedString(@"Restoring accounts from backup", @"")];

    [self inTransaction:^(FMDatabase *db, BOOL *rollback) {

        // 2. Account labels.
        __block NSInteger maxIndex = -1;
        [backup enumerateAccounts:^(NSString *label, NSInteger accIndex, BOOL archived, BOOL current) {
            if (accIndex > maxIndex) maxIndex = accIndex;

            MYCWalletAccount* acc = [MYCWalletAccount loadAccountAtIndex:accIndex fromDatabase:db];
            acc = acc ?: [[MYCWalletAccount alloc] initWithKeychain:[rootKeychain keychainForAccount:(uint32_t)accIndex]];

            if (label.length > 0) {
                acc.label = label;
            }
            acc.archived = archived;
            acc.current = current;

            NSError* dberror = nil;
            MYCLog(@"MYCWallet applyWalletBackup: restoring from backup account %@: %@ archived:%@ current:%@",
                   @(acc.accountIndex),
                   acc.label,
                   @(acc.isArchived),
                   @(acc.isCurrent));
            if (![acc saveInDatabase:db error:&dberror]) {
                MYCError(@"MYCWallet applyWalletBackup: cannot save account at index %@: %@", @(accIndex), dberror);
                *rollback = YES;
                return;
            }
        }];

        // Check if cancelled.
        if (*rollback) return;

        // Make sure we don't have gaps in the accounts list (maxIndex is not checked because it's just created).
        for (NSInteger i = 0; i < maxIndex; i++) {

            MYCWalletAccount* acc = [MYCWalletAccount loadAccountAtIndex:i fromDatabase:db];
            if (!acc) {
                MYCError(@"MYCWallet applyWalletBackup: detected a gap in accounts list: %@; creating an account there.", @(i));
                acc = [[MYCWalletAccount alloc] initWithKeychain:[rootKeychain keychainForAccount:(uint32_t)i]];
                NSError* dberror = nil;
                if (![acc saveInDatabase:db error:&dberror]) {
                    MYCError(@"MYCWallet applyWalletBackup: cannot save account at index %@: %@", @(i), dberror);
                    *rollback = YES;
                    return;
                }
            }
        }

        // Make sure we have current account and it's not archived.
        MYCWalletAccount* curAcc = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
        if (!curAcc || curAcc.isArchived) {
            if (curAcc) {
                MYCError(@"MYCWallet applyWalletBackup: current account is archived, unarchiving it: %@", @(curAcc.accountIndex));
            } else {
                MYCError(@"MYCWallet applyWalletBackup: current account is missing, currentizing account 0.");
            }
            curAcc = curAcc ?: [MYCWalletAccount loadAccountAtIndex:0 fromDatabase:db];
            curAcc.archived = NO;
            curAcc.current = YES;
            NSError* dberror = nil;
            if (![curAcc saveInDatabase:db error:&dberror]) {
                MYCError(@"MYCWallet applyWalletBackup: cannot save current account at index %@: %@", @(curAcc.accountIndex), dberror);
                *rollback = YES;
                return;
            }
        }

        // 3. Tx labels and receipts.
        NSArray* txdetails = backup.transactionDetails;
        for (MYCTransactionDetails* txdet in txdetails) {
            NSError* dberror = nil;
            if (![txdet saveInDatabase:db error:&dberror]) {
                MYCError(@"MYCWallet applyWalletBackup: cannot save transaction details %@: %@", txdet.transactionID, dberror);
                *rollback = YES;
                return;
            } else {
                MYCLog(@"MYCWallet applyWalletBackup: saved transaction details for tx %@", txdet.transactionID);
            }
        }
    }];

    [self setStoredBackupData:[backup dataWithBackupKey:self.backupKey]];

    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidReloadNotification object:self];
}

- (NSData*) storedBackupData {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"MYCWalletStoredEncryptedBackupV1"];
}

- (void) setStoredBackupData:(NSData*)data {
    if (data) {
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"MYCWalletStoredEncryptedBackupV1"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"MYCWalletStoredEncryptedBackupV1"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSData*) backupKey {
    __block NSData* bakmaster = nil;
    [self unlockWallet:^(MYCUnlockedWallet *uw) {
        bakmaster = uw.backupMasterKey;
    } reason:@"Accessing key for automatic wallet backups"];
    return [BTCEncryptedBackup backupKeyForNetwork:self.network masterKey:bakmaster];
}

- (void) uploadAutomaticBackup:(void(^)(BOOL result, NSError* error))completionBlock {

    NSString* walletID = self.backupWalletID;
    NSData* data = [self backupData];

    // Verify that we can decrypt the backup we just created.
    MYCWalletBackup* bak = [[MYCWalletBackup alloc] initWithData:data backupKey:self.backupKey];
    NSDictionary* dict = bak.dictionary;

    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        MYCError(@"Cannot decrypt the encrypted backup (sanity check)");
        completionBlock(NO, [NSError errorWithDomain:MYCErrorDomain code:-6 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Backup encryption inconsistency", @"Automatic backup for wallet data cannot be done.")}]);
        return;
    }

    // Ask system for some background goodness.
    _backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"MYCWallet_backup" expirationHandler:^{
    }];

    MYCLog(@"MYCWallet: Uploading encrypted backup to iCloud Drive and Mycelium: %@ bytes (%@)", @(data.length), walletID);
    [[[MYCCloudKit alloc] init] uploadDataBackup:data walletID:walletID completionHandler:^(BOOL icloudResult, NSError *icloudError) {
        MYCLog(@"MYCWallet: iCloud upload status: %@ %@", @(icloudResult), icloudError ?: @"");
        [self.backend uploadDataBackup:data apub:self.backupAuthenticationKey.publicKey completionHandler:^(BOOL mycResult, NSError *mycError) {
            MYCLog(@"MYCWallet: Mycelium upload status: %@ %@", @(mycResult), mycError ?: @"");
            if (icloudResult || mycResult) {
                [self setStoredBackupData:data];
            }

            if (_backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskIdentifier];
                _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }

            completionBlock(icloudResult || mycResult, icloudError ?: mycError);
        }];
    }];
}

- (void) downloadAutomaticBackup:(void(^)(BOOL result, NSError* error))completionBlock {

    NSString* walletID = self.backupWalletID;

    MYCLog(@"MYCWallet: Downloading encrypted backup from iCloud Drive and Mycelium: %@", walletID);
    [[[MYCCloudKit alloc] init] downloadDataBackupForWalletID:walletID completionHandler:^(NSData *icloudData, NSError *icloudError) {
        MYCLog(@"MYCWallet: iCloud download status: %@ bytes %@", @(icloudData.length), icloudError ?: @"");
        [self.backend downloadDataBackupForWalletID:walletID completionHandler:^(NSData *mycData, NSError *mycError) {
            MYCLog(@"MYCWallet: Mycelium download status: %@ bytes %@", @(mycData.length), mycError ?: @"");

            NSMutableArray* datas = [NSMutableArray array];
            if (icloudData) [datas addObject:icloudData];
            if (mycData) [datas addObject:mycData];

            MYCWalletBackup* backup = [self chooseLatestWalletBackupFromDatas:datas];

            if (!backup) {
                MYCError(@"MYCWallet: could not receive or decrypt any backup data: %@ %@", icloudError ?: @"", mycError ?: @"");
                completionBlock(NO, icloudError ?: mycError);
                return;
            }

            if (backup.network != self.network) {
                MYCError(@"MYCWallet: backup network does not match the current one: %@ != %@", backup.network.paymentProtocolName, self.network.paymentProtocolName);
                completionBlock(NO, [NSError errorWithDomain:MYCErrorDomain code:-573 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Backed up payment data was saved for the different bitcoin network.", @"Errors")}]);
                return;
            }

            MYCLog(@"Applyign backup for %@ from %@", walletID, backup.date);
            [self applyWalletBackup:backup];
            completionBlock(YES, nil);
        }];
    }];
}

- (NSTimeInterval) backupDelay {
    return 10;
}

- (void) setNeedsBackup {

    _needsBackup = YES;
    MYCLog(@"MYCWallet: NEEDS BACKUP.");

    if (!_lastBackupDate) _lastBackupDate = [NSDate date];
    NSTimeInterval remainingTime = [self backupDelay] - [[NSDate date] timeIntervalSinceDate:_lastBackupDate];
    if (remainingTime <= 0) {
        [self backupIfNeeded];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remainingTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self backupIfNeeded];
        });
    }
}

- (void) backupIfNeeded {

    if (!_needsBackup) return;
    if (_backingUp) return;

    _needsBackup = NO;
    _backingUp = YES;
    MYCLog(@"MYCWallet: BACKING UP NOW.");
    [self uploadAutomaticBackup:^(BOOL result, NSError *error) {
        if (result) {
            _lastBackupError = nil;
        } else {
            _lastBackupError = error;
        }
        // Even in case of error, do not backup immediately after scheduling.
        _lastBackupDate = [NSDate date];
        _backingUp = NO;

        // If asked to backup while we were backing up, do it again.
        [self backupIfNeeded];

        [self showLastBackupErrorAlertIfNeeded];
    }];
}

// Returns and erases most recent error during backup.
// So the UI can show the user "Cannot backup, please check your network or iCloud settings."
- (NSError*) popBackupError {
    if (_lastBackupError) {
        NSError* err = _lastBackupError;
        _lastBackupDate = nil;
        return err;
    }
    return nil;
}

- (BOOL) showLastBackupErrorAlertIfNeeded {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        NSError* error = [self popBackupError];
        if (error) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot back up wallet", @"")
                                        message:error.localizedDescription ?: @""
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                              otherButtonTitles:nil] show];
            return YES;
        }
    }
    return NO;
}



- (MYCWalletBackup*) chooseLatestWalletBackupFromDatas:(NSArray*)datas {

    MYCWalletBackup* latestBackup = nil;
    NSUInteger i = 0;
    for (NSData* data in datas) {
        MYCWalletBackup* backup = [[MYCWalletBackup alloc] initWithData:data backupKey:self.backupKey];
        if (!backup) {
            MYCError(@"MYCWallet: Cannot decrypt backup data #%@ (%@ bytes)", @(i), @(data.length));
        } else {
            if (!latestBackup) {
                latestBackup = backup;
            } else {
                NSTimeInterval time = [backup.date timeIntervalSinceDate:latestBackup.date];
                if (time > 0) {
                    MYCLog(@"Have backup with a different date: %@ > %@", backup.date, latestBackup.date);
                }
            }
        }
        i++;
    }
    return latestBackup;
}





// Database Access



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

        [NSException raise:@"CANNOT OPEN DATABASE" format:@"%@", error];

#if 0
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
#endif
    }

    // Database file flags

    {
        // Note: SQLite DB file encryption is provided by global App ID settings (complete file protection).
        // The secret is always protected since it's stored in Keychain with setting "this device only, when unlocked only".

        // Prevent database file from iCloud backup
        if (![database.URL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error])
        {
            MYCError(@"WARNING: Can not exclude database file from backup (%@)", error);
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

- (NSData*) exportDatabaseData {

    NSURL* dburl = self.database.URL;
    if (!dburl) {
        MYCError(@"Cannot get the database path on disk!");
        return nil;
    }
    NSData* data1 = [NSData dataWithContentsOfURL:dburl];
    if (!data1) {
        MYCError(@"Cannot read database from disk while it's open.");
        return nil;
    }
    [self.database close];
    self.database = nil;

    NSData* data2 = [NSData dataWithContentsOfURL:dburl];
    if (!data2) {
        MYCError(@"Cannot read database from disk while it's closed.");
        return nil;
    }
    if (![data1 isEqual:data2]) {
        MYCError(@"Have read different data after closing DB (%@ -> %@ bytes)", @(data1.length), @(data2.length));
        return data2;
    }

    _database = [self openDatabase];
    return data2;
}

- (void) importDatabaseData:(NSData*)data {

    if (!data) [NSException raise:@"No data for importing to DB" format:@"Called -[MYCWallet importDatabaseData]"];
    NSURL* dburl = self.database.URL;

    [self.database close];
    self.database = nil;

    [data writeToURL:dburl atomically:YES];

    _database = [self openDatabase];
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
    } reason:@"Authorize access to seed to reset database."];
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

    [self updateCurrencyFormatter:self.primaryCurrencyFormatter completionHandler:^(BOOL result, NSError *error) {
        if (!result) {
            if (completion) completion(NO, error);
            [self notifyNetworkActivity];
            return;
        }
        [self updateCurrencyFormatter:self.secondaryCurrencyFormatter completionHandler:^(BOOL result, NSError *error) {
            if (!result) {
                if (completion) completion(NO, error);
                [self notifyNetworkActivity];
                return;
            }
            // Remember when we last updated it.
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"MYCWalletCurrencyRateUpdateDate"];

            if (completion) completion(YES, nil);

            [self notifyNetworkActivity];
        }];
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
            [self updateFiatAmountForTransaction:mtx force:NO database:db];
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
    [self updateActiveAccountsForce:NO completionBlock:completion];
}

- (void) updateActiveAccountsForce:(BOOL)force completionBlock:(void(^)(BOOL success, NSError *error))completion
{
    [self asyncInDatabase:^id(FMDatabase *db, NSError *__autoreleasing *dberrorOut) {
        return [MYCWalletAccount loadWithCondition:@"archived = 0" fromDatabase:db];
    } completion:^(NSArray* accs, NSError *dberror) {
        if (!accs)
        {
            if (completion) completion(NO, dberror);
            return;
        }
        [self recursivelyUpdateAccounts:accs force:force completion:completion];
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

// Updates tx details with up-to-date fiat amount and code.
// If force is NO, it will note overwrite existing record should it exist already.
- (void) updateFiatAmountForTransaction:(MYCTransaction*)tx force:(BOOL)force database:(FMDatabase *)db {

    if (!tx || !tx.transactionHash) return;

    [tx loadDetailsFromDatabase:db];

    if (tx.amountTransferred == 0) {
        MYCError(@"MYCWallet: amountTransferred for tx %@ is zero, cannot update fiat amount/code.", tx.transactionID);
        return;
    }

    MYCTransactionDetails* txdet = tx.transactionDetails ?:
    [MYCTransactionDetails loadWithPrimaryKey:@[tx.transactionHash] fromDatabase:db] ?: [[MYCTransactionDetails alloc] init];

    // If we have data already and we do not need to force update, do nothing.
    if (!force && txdet.fiatAmount.length > 0 && txdet.fiatCode.length > 0) {
        return;
    }

    BTCCurrencyConverter* converter = [MYCWallet currentWallet].fiatCurrencyFormatter.currencyConverter;

    if (!converter) {
        MYCError(@"MYCWallet: do not have fiatCurrencyFormatter.currencyConverter to store fiat amount+code.");
        return;
    }

    txdet.transactionHash = tx.transactionHash;
    NSDecimalNumber* num = [converter fiatFromBitcoin:tx.amountTransferred];
    txdet.fiatAmount = num.stringValue;
    if ([txdet.fiatAmount isEqualToString:@"0"] || [num isEqual:[NSDecimalNumber zero]]) {
        MYCError(@"MYCWallet: fiatAmount is zero. Not updating.");
        return;
    }
    txdet.fiatCode = converter.currencyCode;

    MYCLog(@"MYCWallet: updating tx %@ fiat amount: %@ %@",
           txdet.transactionID,
           txdet.fiatAmount,
           txdet.fiatCode);

    NSError* dberror = nil;
    if (![txdet saveInDatabase:db error:&dberror]) {
        MYCError(@"MYCWallet: cannot save tx details for %@ with %@ %@: %@",
                 txdet.transactionID,
                 txdet.fiatAmount,
                 txdet.fiatCode,
                 dberror
                 );
        return;
    }

    [self setNeedsBackup];
}


- (void) notifyNetworkActivity
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateNetworkActivityNotification object:self];
}


- (NSString*) diagnosticsLog {
    return _log ?: @"";
}

- (void) log:(NSString*)message {
    if (!_log) _log = [NSMutableString string];
    if (_log.length > 1000000) {
        _log = [[_log substringFromIndex:500000] mutableCopy];
    }
    [_log appendFormat:@"%@ %@ %@\n", [NSDate date], [NSThread currentThread], message];
}

- (void) logError:(NSString*)message {
    if (!_log) _log = [NSMutableString string];
    if (_log.length > 1000000) {
        _log = [[_log substringFromIndex:500000] mutableCopy];
    }
    [_log appendFormat:@"%@ %@ ERROR: %@\n", [NSDate date], [NSThread currentThread], message];
}

@end
