//
//  MYCCloudKit.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCCloudKit : NSObject

- (void) uploadDataBackup:(NSData*)encryptedData walletID:(NSString*)walletID completionHandler:(void(^)(BOOL result, NSError* error))completionHandler;

- (void) downloadDataBackupForWalletID:(NSString*)walletID completionHandler:(void(^)(NSData* data, NSError* error))completionHandler;

@end
