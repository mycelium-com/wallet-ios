//
//  MYCTransactionDetailsViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTabBarController.h"

@class MYCTransaction;
@interface MYCTransactionDetailsViewController : MYCTabViewController

@property(nonatomic) UIColor* redColor;
@property(nonatomic) UIColor* greenColor;
@property(nonatomic) MYCTransaction* transaction;

@end
