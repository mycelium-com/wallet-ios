//
//  MYCTabBarController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MYCBalanceViewController;
@class MYCAccountsViewController;
@class MYCTransactionsViewController;
@class MYCSettingsViewController;

@interface MYCTabBarController : UITabBarController

@property(nonatomic) MYCBalanceViewController* balanceController;
@property(nonatomic) MYCAccountsViewController* accountsController;
@property(nonatomic) MYCTransactionsViewController* transactionsController;
@property(nonatomic) MYCSettingsViewController* settingsController;

- (void) manageAccounts:(id)sender;

@end

@interface MYCTabViewController : UIViewController

@property(nonatomic) UIColor* tintColor;

@end

