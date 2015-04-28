//
//  MYCWalletBackup.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, MYCWalletBackupVersion) {
    MYCWalletBackupVersion1 = 1,
};

@class MYCCurrencyFormatter;
@interface MYCWalletBackup : NSObject

// Decrypts and decodes backup from binary data.
- (nullable id) initWithData:(nonnull NSData*)data backupKey:(nonnull NSData*)backupKey;

// Instantiates a new instance.
- (nonnull id) init;

// Encodes and encrypts the backup with a given backup key.
- (nonnull NSData*) dataWithBackupKey:(nonnull NSData*)backupKey;


// Properties

@property(nonatomic) MYCWalletBackupVersion version;

// For which network this data is assigned to.
@property(nonatomic, nonnull) BTCNetwork* network;

// Timestamp of the backup.
@property(nonatomic, nonnull) NSDate* date;

// Saved primary currency formatter.
@property(nonatomic, nullable) MYCCurrencyFormatter* currencyFormatter;

- (nonnull NSDictionary*) dictionary;

// Payment details and receipts, array of MYCTransactionDetails instances.
@property(nonatomic, nonnull) NSArray* transactionDetails;

// Saves accounts in this backup.
- (void) setAccounts:(nonnull NSArray*)accounts;

// {"type": "bip44",  "label": "label for bip44 account 0",  "path": "44'/0'/0'", "archived": false, "current": false},
- (void) enumerateAccounts:(void(^ __nonnull)(NSString* __nullable label, NSInteger accountIndex, BOOL archived, BOOL current))block;


@end
