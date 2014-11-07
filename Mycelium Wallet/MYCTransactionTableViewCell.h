//
//  MYCTransactionTableViewCell.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MYCTransaction;
@interface MYCTransactionTableViewCell : UITableViewCell

@property(nonatomic) UIColor* greenColor;
@property(nonatomic) UIColor* redColor;
@property(nonatomic) NSString* formattedAmount;
@property(nonatomic) MYCTransaction* transaction;

@end
