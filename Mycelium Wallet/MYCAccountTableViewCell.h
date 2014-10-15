//
//  MYCAccountTableViewCell.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 15.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MYCWalletAccount;
@interface MYCAccountTableViewCell : UITableViewCell

@property(nonatomic) MYCWalletAccount* account;

@end
