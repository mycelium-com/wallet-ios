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
@property(nonatomic, nonnull) BTCNetwork* network;
// Timestamp of the backup.
@property(nonatomic, nonnull) NSDate* date;

@property(nonatomic, nullable) MYCCurrencyFormatter* currencyFormatter;

- (nonnull NSDictionary*) dictionary;

@end
