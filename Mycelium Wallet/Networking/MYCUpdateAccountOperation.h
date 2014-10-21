//
//  MYCUpdateAccountOperation.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MYCWallet;
@class MYCWalletAccount;
@interface MYCUpdateAccountOperation : NSObject

// Wallet
@property(nonatomic, weak) MYCWallet* wallet;

// Account being updated.
@property(nonatomic, readonly) MYCWalletAccount* account;

// Number of external addresses to look ahead while discovering new transactions.
// Default is 20.
@property(nonatomic) NSInteger externalAddressesLookAhead;

// Number of change addresses to look ahead while discovering new transactions.
// Default is 2.
@property(nonatomic) NSInteger internalAddressesLookAhead;

// Flag controlling if the discovery must be performed.
// Default is YES.
@property(nonatomic) BOOL discoveryEnabled;

// Creates new operation object with a given account.
- (id) initWithAccount:(MYCWalletAccount*)account wallet:(MYCWallet*)wallet;

// Performs account update. Calls the completion block on success or failure.
- (void) update:(void(^)(BOOL success, NSError* error))completion;

@end
