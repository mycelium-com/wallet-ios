//
//  MYCCurrencyTableViewCell.h
//  Mycelium Wallet
//
//  Created by Pascal Edmond on 09/03/2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBitcoin/CoreBitcoin.h>

@class MYCCurrencyFormatter;
@interface MYCCurrencyTableViewCell : UITableViewCell

@property(nonatomic) BTCAmount amount;
@property(nonatomic) MYCCurrencyFormatter* formatter;

@end
