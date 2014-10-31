//
//  MYCWalletAccount.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWallet.h"
#import "MYCWalletAccount.h"

@interface MYCWalletAccount ()
@property(nonatomic) NSTimeInterval syncTimestamp;
@property(nonatomic, readwrite) BTCKeychain* keychain;
@property(nonatomic, readwrite) BTCKeychain* externalKeychain;
@property(nonatomic, readwrite) BTCKeychain* internalKeychain;
@end

@implementation MYCWalletAccount {
    NSMutableDictionary* _externalScriptSearchCache; // [ index NSNumber : script NSData ]
    NSMutableDictionary* _internalScriptSearchCache; // [ index NSNumber : script NSData ]
}

- (id) init
{
    if (self = [super init])
    {
        _externalScriptSearchCache = [NSMutableDictionary dictionary];
        _internalScriptSearchCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id) initWithDictionary:(NSDictionary *)dict
{
    if (self = [super initWithDictionary:dict])
    {
        _externalScriptSearchCache = [NSMutableDictionary dictionary];
        _internalScriptSearchCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id) initWithKeychain:(BTCKeychain*)keychain
{
    // Sanity check.
    if (!keychain) return nil;
    if (!keychain.isHardened) return nil;

    if (self = [super init])
    {
        //NSLog(@"NEW ACCOUNT WITH KEYCHAIN: account:%d first address: %@  extpubkey: %@", (int)keychain.index, [[MYCWallet currentWallet] addressForKey:[keychain externalKeyAtIndex:0]].base58String, keychain);
        _accountIndex = keychain.index;
        _extendedPublicKey = keychain.extendedPublicKey;
        _label = [NSString stringWithFormat:NSLocalizedString(@"Account %@", @""), @(_accountIndex)];
        _keychain = keychain.isPrivate ? keychain.publicKeychain : keychain;
        _syncTimestamp = 0.0;

        _externalScriptSearchCache = [NSMutableDictionary dictionary];
        _internalScriptSearchCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

- (BTCKeychain*) keychain
{
    @synchronized(self)
    {
        if (!_keychain)
        {
            _keychain = [[BTCKeychain alloc] initWithExtendedKey:_extendedPublicKey];
        }
        return _keychain;
    }
}

- (BTCKeychain*) externalKeychain
{
    @synchronized(self)
    {
        if (!_externalKeychain)
        {
            _externalKeychain = [self.keychain derivedKeychainAtIndex:0 hardened:NO];
        }
        return _externalKeychain;
    }
}

- (BTCKeychain*) internalKeychain
{
    @synchronized(self)
    {
        if (!_internalKeychain)
        {
            _internalKeychain = [self.keychain derivedKeychainAtIndex:1 hardened:NO];
        }
        return _internalKeychain;
    }
}

// Currently available external address to receive payments on.
- (BTCPublicKeyAddress*) externalAddress
{
    return [self.wallet addressForKey:[self.externalKeychain keyAtIndex:self.externalKeyIndex]];
}

// Currently available internal (change) address to receive payments on.
- (BTCPublicKeyAddress*) internalAddress
{
    return [self.wallet addressForKey:[self.internalKeychain keyAtIndex:self.internalKeyIndex]];
}

- (BTCSatoshi) unconfirmedAmount
{
    return self.confirmedAmount + self.pendingChangeAmount + self.pendingReceivedAmount - self.pendingSentAmount;
}

- (BTCSatoshi) spendableAmount
{
    return self.confirmedAmount + self.pendingChangeAmount;
}

- (BTCSatoshi) receivingAmount
{
    return self.pendingReceivedAmount;
}

- (BTCSatoshi) sendingAmount
{
    return self.pendingSentAmount - self.pendingChangeAmount;
}

- (NSString*) debugBalanceDescription
{
    NSMutableString* s = [NSMutableString stringWithFormat:@"Spendable: %@", @(self.spendableAmount)];

    if (self.confirmedAmount != self.spendableAmount)
    {
        [s appendFormat:@" (confirmed %@)", @(self.confirmedAmount)];
    }

    if (self.receivingAmount > 0)
    {
        [s appendFormat:@" Receiving: %@", @(self.receivingAmount)];
    }

    if (self.sendingAmount > 0)
    {
        [s appendFormat:@" Sending: %@", @(self.sendingAmount)];
    }

    return s;
}

- (NSDate *) syncDate
{
    if (self.syncTimestamp > 0.0) {
        return [NSDate dateWithTimeIntervalSince1970:self.syncTimestamp];
    } else {
        return nil;
    }
}

- (void)setSyncDate:(NSDate *)syncDate
{
    if (syncDate) {
        self.syncTimestamp = [syncDate timeIntervalSince1970];
    } else {
        self.syncTimestamp = 0.0;
    }
}

// Otherwise MYCDatabaseColumn yields a warning about unrecognized selector.
- (BOOL) archived { return self.isArchived; }
- (BOOL) current { return self.isCurrent; }




- (NSUInteger) externalIndexForScriptData:(NSData*)data startIndex:(NSUInteger)startIndex limit:(NSUInteger)limit
{
    return [self impl_indexForScriptData:data keychain:self.externalKeychain cache:_externalScriptSearchCache startIndex:startIndex limit:limit];
}

- (NSUInteger) internalIndexForScriptData:(NSData*)data startIndex:(NSUInteger)startIndex limit:(NSUInteger)limit
{
    return [self impl_indexForScriptData:data keychain:self.internalKeychain cache:_internalScriptSearchCache startIndex:startIndex limit:limit];
}

- (NSUInteger) impl_indexForScriptData:(NSData*)data keychain:(BTCKeychain*)keychain cache:(NSMutableDictionary*)searchCache startIndex:(NSUInteger)startIndex limit:(NSUInteger)limit
{
    if (!data || !keychain) return NSNotFound;

    @synchronized(self)
    {
        for (NSUInteger i = startIndex; i < (startIndex + limit); i++)
        {
            // Try to get script data for this index from the cache.
            // If not found, compute it and put it in cache.
            NSNumber* j = @(i);
            NSData* ithData = searchCache[j];
            if (!ithData)
            {
                BTCKey* key = [keychain keyAtIndex:(uint32_t)i];
                BTCScript* script = [[BTCScript alloc] initWithAddress:key.address];
                // Cache this value to avoid computing again.
                ithData = script.data;
                searchCache[j] = ithData;
                //NSLog(@"cache miss: %@ (%p)", j, self);
            }
            else
            {
                //NSLog(@"cache hit:  %@", j);
            }

            if ([ithData isEqual:data])
            {
                return i;
            }
        }

        return NSNotFound;
    }
}

// Check if this script data matches one of the addresses in this account.
// Checks within the window of known used addresses.
// If YES, sets change (0 for external, 1 for internal chain) and keyIndex (index of the address).
- (BOOL) matchesScriptData:(NSData*)scriptData change:(NSInteger*)changeOut keyIndex:(NSInteger*)keyIndexOut
{
    if (!scriptData) return NO;

    NSUInteger i = [self externalIndexForScriptData:scriptData startIndex:0 limit:self.externalKeyIndex + 1];
    if (i != NSNotFound)
    {
        if (changeOut) *changeOut = 0;
        if (keyIndexOut) *keyIndexOut = i;
        return YES;
    }

    i = [self internalIndexForScriptData:scriptData startIndex:self.internalKeyStartingIndex limit:self.internalKeyIndex + 1 - self.internalKeyStartingIndex];
    if (i != NSNotFound)
    {
        if (changeOut) *changeOut = 1;
        if (keyIndexOut) *keyIndexOut = i;
        return YES;
    }

    return NO;
}





#pragma mark - Database Access


// Loads current active account from database.
+ (MYCWalletAccount*) loadCurrentAccountFromDatabase:(FMDatabase*)db
{
    return [[self loadWithCondition:@"current = 1 LIMIT 1" fromDatabase:db] firstObject];
}

// Loads all accounts from database.
+ (NSArray*) loadAccountsFromDatabase:(FMDatabase*)db
{
    return [self loadWithCondition:@"1 ORDER BY accountIndex" fromDatabase:db];
}

// Loads a specific account at index from database.
// If account does not exist, returns nil.
+ (MYCWalletAccount*) loadAccountAtIndex:(NSInteger)index fromDatabase:(FMDatabase*)db
{
    return [self loadWithPrimaryKey:@(index) fromDatabase:db];
}







#pragma mark - MYCDatabaseRecord


+ (NSString *)tableName
{
    return @"MYCWalletAccounts";
}

+ (id) primaryKeyName
{
    return @"accountIndex";
}

+ (NSArray *)columnNames
{
    return @[MYCDatabaseColumn(accountIndex),
             MYCDatabaseColumn(label),
             MYCDatabaseColumn(extendedPublicKey),
             MYCDatabaseColumn(confirmedAmount),
             MYCDatabaseColumn(pendingChangeAmount),
             MYCDatabaseColumn(pendingReceivedAmount),
             MYCDatabaseColumn(pendingSentAmount),
             MYCDatabaseColumn(archived),
             MYCDatabaseColumn(current),
             MYCDatabaseColumn(externalKeyIndex),
             MYCDatabaseColumn(internalKeyIndex),
             MYCDatabaseColumn(internalKeyStartingIndex),
             MYCDatabaseColumn(syncTimestamp),
             ];
}

@end
