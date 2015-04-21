//
//  MYCWalletBackup.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCWalletBackup : NSObject

// Encodes the backup into binary data with default compression setting.
@property(nonnull, nonatomic, readonly) NSData* data;

// Decodes backup from binary data (prefixed with a single-byte format version).
- (nullable id) initWithData:(nonnull NSData*)data;

@end
