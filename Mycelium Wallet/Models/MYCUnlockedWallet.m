//
//  MYCUnlockedWallet.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 08.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCUnlockedWallet.h"
#import "MYCWallet.h"
#import <Security/Security.h>

#define kMasterSeedName @"MasterSeed"
#define kBackupMasterKeyName @"BackupMasterKeyV2"
#define kProbeItemName  @"ProbeItem"

@interface MYCUnlockedWallet ()
@end

@implementation MYCUnlockedWallet {
}

@synthesize mnemonic=_mnemonic;
@synthesize backupMasterKey=_backupMasterKey;

- (NSString*) serviceName {
    return @"MyceliumWallet";
}

- (BTCMnemonic*) readMnemonic {

    BTCMnemonic* m = self.mnemonic;

    if (m) return m;

    MYCError(@"Keychain-based mnemonic not found or cannot be accessed: %@", self.error);

    // do not return fileBasedMnemonic
    return nil;
}

- (BTCMnemonic*) mnemonic {
    if (!_mnemonic) {
        NSError* error = nil;
        NSData* data = [self readItemWithName:kMasterSeedName error:&error];
        if (!data) {
            MYCError(@"MYCUnlockedWallet: Cannot read mnemonic from keychain: %@", error);
            self.error = error;
            return nil;
        }
        _mnemonic = [[BTCMnemonic alloc] initWithData:data];
    }
    return _mnemonic;
}

- (void) setMnemonic:(BTCMnemonic *)mnemonic {

    _mnemonic = mnemonic;
    NSError* error = nil;
    NSData* data = mnemonic.dataWithSeed ?: [NSData data];
    if (![self writeItem:data
                withName:kMasterSeedName
                   error:&error]) {
        MYCError(@"MYCUnlockedWallet: Cannot write mnemonic to keychain: %@", error);
        self.error = error;
        return;
    }

    // Also save the backup master key so we don't need to access mnemonic needlessly (good for forward compatibility).
    self.backupMasterKey = [self backupMasterKeyFromMnemonic:mnemonic];
}

- (NSData*) backupMasterKey {
    if (!_backupMasterKey) {
        NSError* error = nil;
        NSData* data = [self readItemWithName:kBackupMasterKeyName error:&error];
        if (!data) {
            data = [self backupMasterKeyFromMnemonic:self.mnemonic];
            if (data) {
                MYCError(@"MYCUnlockedWallet: Cannot read backupMasterKey from keychain: %@", error);
                self.backupMasterKey = data;
            } else {
                MYCError(@"MYCUnlockedWallet: Cannot read backupMasterKey from keychain: %@ (also cannot read mnemonic: %@)", error, self.error);
                self.error = error;
                return nil;
            }
        }
        _backupMasterKey = data;
    }
    return _backupMasterKey;
}

- (NSData*) backupMasterKeyFromMnemonic:(BTCMnemonic*)mnemonic {
    if (!mnemonic) return nil;
    // We use Mycelium-specific derivation here to avoid clashes with alternative backup schemas.
    return BTCHMACSHA256(mnemonic.seed, [@"Mycelium Backup Master Key" dataUsingEncoding:NSASCIIStringEncoding]);
}

- (void) setBackupMasterKey:(NSData *)backupMasterKey {

    _backupMasterKey = backupMasterKey;
    NSError* error = nil;
    if (![self writeItem:backupMasterKey
                withName:kBackupMasterKeyName
                   error:&error]) {
        MYCError(@"MYCUnlockedWallet: Cannot write backupMasterKey to keychain: %@", error);
        self.error = error;
        return;
    }
}

- (NSData*) probeItemValue {
    return [@"probe" dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL) probeItem {
    NSError* error = nil;
    NSData* data = [self readItemWithName:kProbeItemName error:&error];
    if (!data) {
        MYCError(@"MYCUnlockedWallet: Cannot read probe item from keychain: %@", error);
        self.error = error;
        return NO;
    }
    if ([data isEqual:[self probeItemValue]]) {
        return YES;
    }
    self.error = [NSError errorWithDomain:MYCErrorDomain
                                     code:-3
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                NSLocalizedString(@"Failed to read a correct probe item value from iOS Keychain.", @"")}];
    return NO;
}

- (void) setProbeItem:(BOOL)probeItem {
    NSData* data = probeItem ? [self probeItemValue] : nil;
    NSError* error = nil;
    if (![self writeItem:data
                withName:kProbeItemName
                   error:&error]) {
        MYCError(@"MYCUnlockedWallet: Cannot write probe item to keychain: %@", error);
        self.error = error;
        return;
    }
}

- (NSURL*) seedFileURL {
    NSURL *documentsFolderURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *url = [NSURL URLWithString:@"MasterSeed.txt" relativeToURL:documentsFolderURL].absoluteURL;

    if (!url) {
        [NSException raise:@"Internal Inconsistency" format:@"Failed to construct a URL for MasterSeed file"];
    }
    return url;
}

- (BOOL) fileBasedMnemonicIsStored {
    MYCLog(@"Checking if file exists at path %@", [self seedFileURL].path);
    return [[NSFileManager defaultManager] fileExistsAtPath:[self seedFileURL].path];
}

- (BTCMnemonic*) fileBasedMnemonic {
    if (![UIApplication sharedApplication].isProtectedDataAvailable) {
        MYCLog(@"MYCUnlockedWallet: UIApplication isProtectedDataAvailable = NO; cannot read the seed from the file.");
        self.error = [NSError errorWithDomain:MYCErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot read the master seed from the file while device is locked (protected data is not available).", @"")}];
        return nil;
    }

    NSURL* url = [self seedFileURL];
    NSData* data = [[NSData alloc] initWithContentsOfURL:url];

    if (!data) {
        MYCError(@"MYCUnlockedWallet: failed to read master seed from file %@", url);
        self.error = [NSError errorWithDomain:MYCErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot read the master seed from the file.", @"")}];
        return nil;
    }

    // Data is mnemonic data

    BTCMnemonic* mnemonic = [[BTCMnemonic alloc] initWithData:data];
    if (!mnemonic) {
        MYCError(@"MYCUnlockedWallet: failed to read mnemonic from data of %@ bytes", @(data.length));
        self.error = [NSError errorWithDomain:MYCErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot read the master seed from the file.", @"")}];
        return nil;
    }
    return mnemonic;
}

- (void) setFileBasedMnemonic:(BTCMnemonic*)mnemonic {

    if (!mnemonic) {
        [NSException raise:@"Cannot save nil mnemonic" format:@"You should use explicit deletion API if you want to erase mnemonic."];
        return;
    }

    NSData* data = mnemonic.dataWithSeed;

    if (!data || data.length < 128/8) {
        [NSException raise:@"Cannot save empty mnemonic" format:@"Mnemonic is malformed, should return data object."];
        return;
    }

    NSURL* url = [self seedFileURL];
    NSError* error = nil;
    if (![data writeToURL:url options:NSDataWritingAtomic|NSDataWritingFileProtectionComplete error:&error]) {
        MYCError(@"Cannot write master seed to file %@ with full protection enabled. Error: %@", url, error);
        self.error = error;
    }

    // Set file protection attributes explicitly & prevent backup

    // Encrypt database file
    if (![[NSFileManager defaultManager] setAttributes:@{ NSFileProtectionKey: NSFileProtectionComplete }
                                          ofItemAtPath:url.path
                                                 error:&error]) {
        MYCError(@"Cannot protect seed file %@ with full protection enabled. Error: %@", url.path, error);
        self.error = error;
        return;
    }

    // Prevent database file from iCloud backup
    if (![url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error])
    {
        MYCError(@"WARNING: Can not exclude seed file from backup (%@)", error);
        self.error = error;
        return;
    }
}

- (BOOL) removeFileBasedMnemonic:(NSString*)reason {
    MYCError(@"WARNING: Removing file-based mnemonic. %@", reason);
    NSError* error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:[self seedFileURL] error:&error]) {
        MYCError(@"Cannot remove master seed file: %@", error);
        self.error = error;
        return NO;
    }
    return YES;
}

- (BOOL) makeFileBasedMnemonicIfNeededWithMnemonic:(BTCMnemonic*)mnemonic {

    if ([self fileBasedMnemonicIsStored]) {
        return YES;
    }
    return [self makeFileBasedMnemonic:mnemonic];
}

- (BOOL) makeFileBasedMnemonic:(BTCMnemonic*)mnemonic {

    if (![UIApplication sharedApplication].isProtectedDataAvailable) {
        self.error = [NSError errorWithDomain:MYCErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot make another copy of master seed while device is locked", @"")}];
        return NO;
    }

    if (!mnemonic) {
        [NSException raise:@"Cannot use nil mnemonic to make file-based copy" format:@""];
        return NO;
    }

    self.error = nil;
    self.fileBasedMnemonic = mnemonic;

    if (self.error) {
        [self removeFileBasedMnemonic:@"Cleaning up after failing to save a file-based mnemonic"];
        return NO;
    }

    BTCMnemonic* mnemonic2 = self.fileBasedMnemonic;
    if (!mnemonic2) {
        [self removeFileBasedMnemonic:@"Cleaning up after attempt to save a file-based mnemonic and failing to read it"];
        return NO;
    }

    if (![mnemonic2.data isEqual:mnemonic.data]) {
        self.error = [NSError errorWithDomain:MYCErrorDomain code:-3 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Stored seed differs from the one which the app asked to save.", @"")}];
        return NO;
    }
    
    return YES;
}

- (BTCKeychain*) keychain
{
    if (!_keychain)
    {
        BTCMnemonic* mnemonic = [self readMnemonic];
        if (mnemonic) {
            _keychain = (self.wallet.isTestnet ? [mnemonic.keychain bitcoinTestnetKeychain] : [mnemonic.keychain bitcoinMainnetKeychain]);
        }
    }
    return _keychain;
}

- (void) clear
{
    [_mnemonic clear];
    [_keychain clear];
    _mnemonic = nil;
    _keychain = nil;
}

- (void) dealloc
{
    [self clear];
}




#pragma mark - Secret Accessors


- (NSData*) readItemWithName:(NSString*)name error:(NSError**)errorOut {

    MYCLog(@"MYCUnlockedWallet: Reading item with name: %@", name);
    CFDictionaryRef value = NULL;
    NSMutableDictionary * dict = [self keychainBaseDictForItemNamed:name];
    dict[(__bridge id)kSecReturnData] = @YES;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)dict,
                                          (CFTypeRef *)&value);
    if (status == errSecSuccess) {
        return ( __bridge_transfer NSData *)value;
    }
    else if (status == errSecItemNotFound) {
        // We have no data stored there yet, so we don't return an error.
        MYCError(@"MYCUnlockedWallet: Item with name %@ not found", name);
        return nil;
    }

    // We have no data stored there yet, so we don't return an error.
    MYCError(@"MYCUnlockedWallet: Item with name %@ cannot be accessed. Error code: %@", name, @(status));

    if (errorOut) *errorOut = [self errorForOSStatus:status];

    return nil;
}

- (BOOL) writeItem:(NSData*)data
          withName:(NSString*)name
             error:(NSError**)errorOut {

    MYCLog(@"MYCUnlockedWallet: Writing %@ bytes with name: %@", @(data.length), name);
    NSParameterAssert(name);

    // We cannot update the value, only attributes of the keychain items.
    // So to update value we delete the item and add a new one.
    NSMutableDictionary * dict = [self keychainBaseDictForItemNamed:name];
    dict[(__bridge id)kSecReturnData] = @YES;
    OSStatus status1 = SecItemDelete((__bridge CFDictionaryRef)dict);

    if (status1 != errSecSuccess && status1 != errSecItemNotFound) {
        if (errorOut) *errorOut = [self errorForOSStatus:status1];
        return NO;
    }

    if (!data) {
        MYCLog(@"MYCUnlockedWallet: Writing nil data for name %@", name);
        return YES;
    }
    
    [dict removeObjectForKey:(__bridge id)kSecReturnData];
    
    if (!data || data.length == 0) [NSException raise:@"Unexpected value!" format:@"Must provide data to make an iOS keychain create request"];
    dict[(__bridge id)kSecValueData] = data;
    dict[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    CFDictionaryRef attributes = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)dict, (CFTypeRef *)&attributes);
    if (status != errSecSuccess) {
        if (errorOut) *errorOut = [self errorForOSStatus:status];
        return NO;
    }
    return YES;
}



#pragma mark - Apple Keychain Helpers


- (NSMutableDictionary*) keychainBaseDictForItemNamed:(NSString*)name {

    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    dict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

    // IMPORTANT: need to save password with both keys: service + account. kSecAttrGeneric as used in Apple's code does not guarantee uniqueness.
    // http://useyourloaf.com/blog/2010/04/28/keychain-duplicate-item-when-adding-password.html
    // http://stackoverflow.com/questions/4891562/ios-keychain-services-only-specific-values-allowed-for-ksecattrgeneric-key
    dict[(__bridge id)kSecAttrService] = self.serviceName;
    dict[(__bridge id)kSecAttrAccount] = name;

    return dict;
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

- (NSError*) errorForOSStatus:(OSStatus)statusCode {
    return [MYCUnlockedWallet errorForOSStatus:statusCode];
}

+ (NSError*) errorForOSStatus:(OSStatus)statusCode {
    NSString* description = nil;
    NSString* codeName = nil;

    switch (statusCode) {
        case errSecSuccess:
            codeName = @"errSecSuccess";
            description = @"No error.";
            break;
        case errSecUnimplemented:
            codeName = @"errSecUnimplemented";
            description = @"Function or operation not implemented.";
            break;
        case errSecIO:
            codeName = @"errSecIO";
            description = @"I/O error (bummers)";
            break;
        case errSecParam:
            codeName = @"errSecParam";
            description = @"One or more parameters passed to a function where not valid.";
            break;
        case errSecAllocate:
            codeName = @"errSecAllocate";
            description = @"Failed to allocate memory.";
            break;
        case errSecUserCanceled:
            codeName = @"errSecUserCanceled";
            description = @"User canceled the operation.";
            break;
        case errSecBadReq:
            codeName = @"errSecBadReq";
            description = @"Bad parameter or invalid state for operation.";
            break;
        case errSecInternalComponent:
            codeName = @"errSecInternalComponent";
            description = @"";
            break;
        case errSecNotAvailable:
            codeName = @"errSecNotAvailable";
            description = @"No keychain is not available. You may need to restart your computer.";
            break;
        case errSecDuplicateItem:
            codeName = @"errSecDuplicateItem";
            description = @"That password already exists in the keychain.";
            break;
        case errSecItemNotFound:
            codeName = @"errSecItemNotFound";
            description = @"The item could not be found in the keychain.";
            break;
        case errSecInteractionNotAllowed:
            codeName = @"errSecInteractionNotAllowed";
            description = @"User interaction is not allowed.";
            break;
        case errSecDecode:
            codeName = @"errSecDecode";
            description = @"Unable to decode the provided data.";
            break;
        case errSecAuthFailed:
            codeName = @"errSecAuthFailed";
            description = @"The username or password you entered is not correct.";
            break;
        case -34018:
            codeName = @"-34018";
            description = @"Shared Keychain entitlements might be incorrect. Cf. http://stackoverflow.com/questions/20344255/secitemadd-and-secitemcopymatching-returns-error-code-34018-errsecmissingentit";
            break;
        default:
            codeName = @(statusCode).stringValue;
            description = @"Other keychain error.";
            break;
    }

    return [NSError errorWithDomain:MYCErrorDomain
                               code:statusCode
                           userInfo:@{NSLocalizedDescriptionKey:
                                          [NSString stringWithFormat:@"%@ (%@)",
                                           description, codeName]}];
}


+ (BOOL) isPasscodeSet {

    BOOL apiAvailable = (kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly != NULL);

    if (!apiAvailable) return NO;

    OSStatus status;

    // delete the item to resolve some entitlements and security issues when running from Xcode debugger
    {
        NSDictionary *query = @{
                                (__bridge id)kSecClass:  (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecAttrService: @"LocalDeviceServices",
                                (__bridge id)kSecAttrAccount: @"NoAccount"
                                };

        status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess || status == errSecItemNotFound) {
            // okay
        } else {
            MYCError(@"MYCUnlockedWallet: failed to delete isPasscodeSet probe: %@", [self errorForOSStatus:status]);
            // interesting.
        }
    }

    // From http://pastebin.com/T9YwEjnL
    NSData* secret = [@"Device has passcode set?" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{
                                 (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                 (__bridge id)kSecAttrService: @"LocalDeviceServices",
                                 (__bridge id)kSecAttrAccount: @"NoAccount",
                                 (__bridge id)kSecValueData: secret,
                                 (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
                                 };

    // Original code claimed to check if the item was already on the keychain
    // but in reality you can't add duplicates so this will fail with errSecDuplicateItem
    // if the item is already on the keychain (which could throw off our check if
    // kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly was not set)

    status = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    if (status == errSecSuccess) { // item added okay, passcode has been set
        NSDictionary *query = @{
                                (__bridge id)kSecClass:  (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecAttrService: @"LocalDeviceServices",
                                (__bridge id)kSecAttrAccount: @"NoAccount"
                                };
        
        status = SecItemDelete((__bridge CFDictionaryRef)query);

        if (status != errSecSuccess) {
            MYCError(@"MYCUnlockedWallet: status after deleting isPasscodeSet probe after successful creation: %@", [self errorForOSStatus:status]);
        }
        return YES;
    }

    MYCError(@"MYCUnlockedWallet: status after setting isPasscodeSet probe (errSecDecode is expected when passcode is not set): %@", [self errorForOSStatus:status]);
    
    // errSecDecode seems to be the error thrown on a device with no passcode set
    if (status == errSecDecode) {
        return NO;
    }
    
    return NO;
}


@end
