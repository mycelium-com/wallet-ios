//
//  MYCTransactionsViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTabBarController.h"

@class MYCWalletAccount;
@interface MYCTransactionsViewController : MYCTabViewController

// If nil, uses current account.
@property(nonatomic) MYCWalletAccount* account;

@end
