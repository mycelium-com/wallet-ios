//
//  MYCAccountTableViewCell.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 15.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCAccountTableViewCell.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCCurrencyFormatter.h"

@interface MYCAccountTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *primaryLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondaryLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end

@implementation MYCAccountTableViewCell

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window)
    {
        [self updateStyle];
    }
}

- (void) tintColorDidChange
{
    [super tintColorDidChange];
    [self updateStyle];
}

- (void) updateStyle
{
    self.statusLabel.textColor = self.tintColor;
    self.secondaryLabel.textColor = self.tintColor;
}

- (void) setAccount:(MYCWalletAccount *)account
{
    _account = account;

    self.nameLabel.text = account.label;
    self.statusLabel.text = @" ";
    if (self.account.isCurrent)
    {
        self.statusLabel.text = [NSLocalizedString(@"Current", @"") uppercaseString];
    }

    MYCWallet* wallet = [MYCWallet currentWallet];

    self.primaryLabel.text = [wallet.primaryCurrencyFormatter stringFromAmount:account.spendableAmount];
    self.secondaryLabel.text = [wallet.secondaryCurrencyFormatter stringFromAmount:account.spendableAmount];
}

@end
