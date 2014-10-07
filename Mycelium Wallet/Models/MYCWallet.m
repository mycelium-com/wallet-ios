//
//  MYCWallet.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWallet.h"
#import "MYCDatabase.h"

#import <Security/Security.h>

@interface MYCUnlockedWallet ()

@property(nonatomic, weak) MYCWallet* wallet;
@property(nonatomic, readwrite) BTCKeychain* keychain;
@property(nonatomic) NSString* reason;

- (id) initWithWallet:(MYCWallet*)wallet;
- (void) clear;

@end


@interface MYCWallet ()
@property(nonatomic) NSURL* databaseURL;
@end

@implementation MYCWallet {
    MYCDatabase* _database;
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
    return nil;
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

    if (_database) _database = [self openDatabase];
}

- (void) unlockWallet:(void(^)(MYCUnlockedWallet*))block reason:(NSString*)reason
{
    MYCUnlockedWallet* unlockedWallet = [[MYCUnlockedWallet alloc] initWithWallet:self];

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

// Returns YES if wallet is fully initialized and stored on disk.
- (BOOL) isStored
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.databaseURL.path];
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
        [database registerMigration:@"createAccounts" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:
                    @"CREATE TABLE accounts("
                    "id                INT PRIMARY KEY NOT NULL,"
                    "label             TEXT            NOT NULL,"
                    "extendedPublicKey TEXT            NOT NULL,"
                    "confirmedAmount   INT             NOT NULL,"
                    "unconfirmedAmount INT             NOT NULL,"
                    "archived          INT             NOT NULL"
                    ")"];
        }];

        [database registerMigration:@"createUnspentOutputs" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:
                    @"CREATE TABLE unspentOutputs("
                    "outpointHash      TEXT NOT NULL,"
                    "outpointIndex     INT  NOT NULL,"
                    "blockHeight       INT  NOT NULL,"
                    "script            TEXT NOT NULL,"
                    "value             INT  NOT NULL,"
                    "accountIndex      INT  NOT NULL,"
                    "type              TEXT NOT NULL," // unspent, change, receiving
                    "PRIMARY KEY (outpointHash, outpointIndex)"
                    ")"] &&
            [db executeUpdate:
             @"CREATE INDEX unspentOutputs_accountIndex ON unspentOutputs (accountIndex)"];
        }];

        [database registerMigration:@"createTransactionSummaries" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
            return [db executeUpdate:
                    @"CREATE TABLE transactionSummaries("
                    "txhash            TEXT NOT NULL,"
                    "data              TEXT NOT NULL,"
                    "blockHeight       INT  NOT NULL,"
                    "accountIndex      INT  NOT NULL,"
                    "PRIMARY KEY (txhash)"
                    ")"]  &&
            [db executeUpdate:
             @"CREATE INDEX transactionSummaries_accountIndex ON transactionSummaries (accountIndex)"];
        }];

        [database registerMigration:@"createDefaultAccount" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {

#warning FIXME: create a default account.
            
            return YES;
        }];
    }


    // Open database

    if (![database open:&error])
    {
        NSLog(@"[%@ %@] error:%@", [self class], NSStringFromSelector(_cmd), error);

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
    
    return database;
}

// Removes database from disk.
- (void) removeDatabase
{
    NSLog(@"WARNING: MYCWallet is removing Mycelium database from disk.");

    if (_database) [_database close];

    _database = nil;
    NSError* error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.databaseURL error:&error];
}

@end



@implementation MYCUnlockedWallet {
}

@synthesize mnemonic=_mnemonic;

- (id) initWithWallet:(MYCWallet*)wallet
{
    if (self = [super init])
    {
        self.wallet = wallet;
    }
    return nil;
}

- (BTCMnemonic*) mnemonic
{
    if (!_mnemonic)
    {
        CFDictionaryRef attributes = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)[self keychainSearchRequestForMnemonic],
                                              (CFTypeRef *)&attributes);
        if (status == errSecSuccess)
        {
            NSDictionary* attrs = (__bridge id)attributes;

            NSData* data = attrs[(__bridge id)kSecValueData];

            if (data && data.length > 0)
            {
                _mnemonic = [[BTCMnemonic alloc] initWithData:data];
            }
            else
            {
                // Not found the data.
                NSLog(@"MYCUnlockedWallet: ERROR: read the keychain item, but the data is %@ (attrs: %@)", data, attrs);
            }
        }
        else if (status == errSecItemNotFound)
        {
            // Not found - we have no mnemonic.
            _mnemonic = nil;
        }
        else
        {
            NSLog(@"MYCUnlockedWallet: ERROR: failed while querying the iOS keychain (getting mnemonic): %d", status);
        }
    }
    return _mnemonic;
}

- (void) setMnemonic:(BTCMnemonic *)mnemonic
{
    _mnemonic = mnemonic;

    CFDictionaryRef attributes = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)[self keychainSearchRequestForMnemonic], (CFTypeRef *)&attributes);
    if (status == errSecSuccess)
    {
        // item found - update.
        status = SecItemUpdate((__bridge CFDictionaryRef)[self keychainSearchRequestForMnemonic],
                               (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: _mnemonic ?: [NSData data]});
        if (status == errSecSuccess)
        {
            // done.
        }
        else
        {
            NSLog(@"MYCUnlockedWallet: ERROR: failed while updating item with mnemonic data in iOS keychain: %d", status);
        }
    }
    else if (status == errSecItemNotFound)
    {
        // not found - create.
        status = SecItemAdd((__bridge CFDictionaryRef)[self keychainUpdateRequestForMnemonic], (CFTypeRef *)&attributes);
        if (status == errSecSuccess)
        {
            // done.
        }
        else
        {
            NSLog(@"MYCUnlockedWallet: ERROR: failed while adding mnemonic data to iOS keychain: %d", status);
        }
    }
    else
    {
        NSLog(@"MYCUnlockedWallet: ERROR: failed while querying the iOS keychain (setting mnemonic): %d", status);
    }
}

// OSStatus values specific to Security framework.
//enum
//{
//    errSecSuccess                               = 0,       /* No error. */
//    errSecUnimplemented                         = -4,      /* Function or operation not implemented. */
//    errSecIO                                    = -36,     /*I/O error (bummers)*/
//    errSecOpWr                                  = -49,     /*file already open with with write permission*/
//    errSecParam                                 = -50,     /* One or more parameters passed to a function where not valid. */
//    errSecAllocate                              = -108,    /* Failed to allocate memory. */
//    errSecUserCanceled                          = -128,    /* User canceled the operation. */
//    errSecBadReq                                = -909,    /* Bad parameter or invalid state for operation. */
//    errSecInternalComponent                     = -2070,
//    errSecNotAvailable                          = -25291,  /* No keychain is available. You may need to restart your computer. */
//    errSecDuplicateItem                         = -25299,  /* The specified item already exists in the keychain. */
//    errSecItemNotFound                          = -25300,  /* The specified item could not be found in the keychain. */
//    errSecInteractionNotAllowed                 = -25308,  /* User interaction is not allowed. */
//    errSecDecode                                = -26275,  /* Unable to decode the provided data. */
//    errSecAuthFailed                            = -25293,  /* The user name or passphrase you entered is not correct. */
//};

- (NSMutableDictionary*) keychainBaseDictForMnemonic
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];

    dict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

    // IMPORTANT: need to save password with both keys: service + account. kSecAttrGeneric as used in Apple's code does not guarantee uniqueness.
    // http://useyourloaf.com/blog/2010/04/28/keychain-duplicate-item-when-adding-password.html
    // http://stackoverflow.com/questions/4891562/ios-keychain-services-only-specific-values-allowed-for-ksecattrgeneric-key
    dict[(__bridge id)kSecAttrService] = @"MyceliumWallet";
    dict[(__bridge id)kSecAttrAccount] = @"MasterSeed";

    return dict;
}

- (NSMutableDictionary*) keychainSearchRequestForMnemonic
{
    NSMutableDictionary* dict = [self keychainBaseDictForMnemonic];

    if (self.reason) dict[(__bridge id)kSecUseOperationPrompt] = self.reason;
    dict[(__bridge id)kSecReturnData] = @YES;

    return dict;
}

- (NSMutableDictionary*) keychainUpdateRequestForMnemonic
{
    NSMutableDictionary* dict = [self keychainBaseDictForMnemonic];

    if (self.reason) dict[(__bridge id)kSecUseOperationPrompt] = self.reason;
    if (_mnemonic) dict[(__bridge id)kSecValueData] = _mnemonic;
    dict[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    return dict;
}

- (BTCKeychain*) keychain
{
    if (!_keychain)
    {
        _keychain = [_mnemonic.keychain copy];
    }
    return _keychain;
}

- (void) clear
{
    [self.mnemonic clear];
    [self.keychain clear];
    _mnemonic = nil;
    _keychain = nil;
}

- (void) dealloc
{
    [self clear];
}

@end
