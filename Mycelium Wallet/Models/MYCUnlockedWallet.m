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

@implementation MYCUnlockedWallet {
}

@synthesize mnemonic=_mnemonic;

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
                MYCError(@"MYCUnlockedWallet: read the keychain item, but the data is %@ (attrs: %@)", data, attrs);
            }
        }
        else if (status == errSecItemNotFound)
        {
            // Not found - we have no mnemonic.
            _mnemonic = nil;
        }
        else
        {
            // if status == -34018, add proper Shared Keychain entitlements
            // http://stackoverflow.com/questions/20344255/secitemadd-and-secitemcopymatching-returns-error-code-34018-errsecmissingentit
            MYCError(@"MYCUnlockedWallet: failed searching iOS keychain (getting mnemonic): %d", (int)status);
        }
    }
    return _mnemonic;
}

- (void) setMnemonic:(BTCMnemonic *)mnemonic
{
    _mnemonic = mnemonic;

    // We cannot update the value, only attributes of the keychain items.
    // So to update value we delete the item and add a new one.

    SecItemDelete((__bridge CFDictionaryRef)[self keychainSearchRequestForMnemonic]);

    if (mnemonic)
    {
        CFDictionaryRef attributes = NULL;
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)[self keychainCreateRequestForMnemonic], (CFTypeRef *)&attributes);
        if (status == errSecSuccess)
        {
            // done.
        }
        else
        {
            MYCError(@"MYCUnlockedWallet: failed to add mnemonic data to iOS keychain: %d", (int)status);
        }
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
    dict[(__bridge id)kSecReturnAttributes] = @YES; // when both ReturnData and ReturnAttributes are specified, result is the dictionary.

    return dict;
}

- (NSMutableDictionary*) keychainCreateRequestForMnemonic
{
    NSMutableDictionary* dict = [self keychainBaseDictForMnemonic];

    if (self.reason) dict[(__bridge id)kSecUseOperationPrompt] = self.reason;
    if (_mnemonic) dict[(__bridge id)kSecValueData] = _mnemonic.dataWithSeed ?: [NSData data];
    dict[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    return dict;
}

- (BTCKeychain*) keychain
{
    if (!_keychain)
    {
        _keychain = (self.wallet.isTestnet ? [self.mnemonic.keychain bitcoinTestnetKeychain] : [self.mnemonic.keychain bitcoinMainnetKeychain]);
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

@end
