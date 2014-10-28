//
//  MYCTransactionTableViewCell.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTransactionTableViewCell.h"
#import "MYCTransaction.h"
#import "MYCWallet.h"

@interface MYCTransactionTableViewCell ()
@property (weak, nonatomic) IBOutlet UILabel *btcLabel;
@property (weak, nonatomic) IBOutlet UILabel *fiatLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@end

@implementation MYCTransactionTableViewCell {
    UIColor* _greenColor;
    UIColor* _redColor;
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    _greenColor = self.btcLabel.textColor;
    _redColor = self.fiatLabel.textColor;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
    _transaction = nil;
}

- (void) setTransaction:(MYCTransaction *)transaction
{
    _transaction = transaction;
    [self updateViews];
}

- (void) updateViews
{
    MYCWallet* wallet = [MYCWallet currentWallet];

    BTCSatoshi amount = self.transaction.amountTransferred;
    self.btcLabel.text = [wallet.btcFormatter stringFromAmount:ABS(amount)];
    self.fiatLabel.text = [wallet.fiatFormatter stringFromNumber:[wallet.currencyConverter fiatFromBitcoin:ABS(amount)]];

    UIColor* amountColor = (amount > 0 ? _greenColor : _redColor);

    self.btcLabel.textColor = amountColor;
    self.fiatLabel.textColor = amountColor;

    self.addressLabel.text = self.transaction.label;

    self.statusLabel.text = @"";

    if (self.transaction.blockHeight == -1)
    {
        self.statusLabel.text = NSLocalizedString(@"Not confirmed yet", @"");
    }
    else
    {
        NSInteger confirmations = 1 + wallet.blockchainHeight - self.transaction.blockHeight;

        if (confirmations == 1)
        {
            self.statusLabel.text = NSLocalizedString(@"1 confirmation", @"");
        }
        else
        {
            self.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ confirmations", @""), @(confirmations)];
        }
    }
}

@end
