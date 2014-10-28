//
//  MYCTransactionDetailsViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MYCTransaction;
@interface MYCTransactionDetailsViewController : UIViewController

@property(nonatomic) MYCTransaction* transaction;

@end
