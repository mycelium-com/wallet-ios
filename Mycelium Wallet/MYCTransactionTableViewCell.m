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
#import "PColor.h"

@interface MYCTransactionTableViewCell ()
@property (weak, nonatomic) IBOutlet UILabel *amountLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@end

@implementation MYCTransactionTableViewCell {
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    _greenColor = self.amountLabel.textColor;
    _redColor = self.dateLabel.textColor;
    self.dateLabel.textColor = [UIColor blackColor];
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

- (void) setFormattedAmount:(NSString *)formattedAmount
{
    _formattedAmount = formattedAmount;
    [self updateViews];
}

- (void) updateViews
{
    MYCWallet* wallet = [MYCWallet currentWallet];

    self.amountLabel.text = _formattedAmount ?: @"0.00";
    BTCSatoshi amount = self.transaction.amountTransferred;
    UIColor* amountColor = (amount > 0 ? _greenColor : _redColor);
    self.amountLabel.textColor = amountColor;

//    self.btcLabel.text = [wallet.btcFormatter stringFromAmount:ABS(amount)];
//    if (amount >= 0)
//    {
//        self.btcLabel.text = [@"+ " stringByAppendingString:self.btcLabel.text];
//    }
//    else
//    {
//        self.btcLabel.text = [@"– " stringByAppendingString:self.btcLabel.text];
//    }
//    self.fiatLabel.text = [wallet.fiatFormatter stringFromNumber:[wallet.currencyConverter fiatFromBitcoin:ABS(amount)]];

    self.statusLabel.text = self.transaction.label ?: @"";

    if (self.transaction.blockHeight == -1)
    {
        self.statusLabel.text = [NSString stringWithFormat:@"%@\n%@",
                                 self.statusLabel.text,
                                 NSLocalizedString(@"Not confirmed yet", @"")];
    }
    else
    {
        NSInteger confirmations = 1 + wallet.blockchainHeight - self.transaction.blockHeight;

        if (confirmations == 1)
        {
            self.statusLabel.text = [NSString stringWithFormat:@"%@\n%@",
                                     self.statusLabel.text,
                                     NSLocalizedString(@"1 confirmation", @"")];
        }
        else if (confirmations <= 999)
        {
            self.statusLabel.text = [NSString stringWithFormat:@"%@\n%@",
                                     self.statusLabel.text,
                                     [NSString stringWithFormat:NSLocalizedString(@"%@ confirmations", @""), @(confirmations)]];
        }
    }

    if ([self.transaction.date timeIntervalSinceNow] > -20*3600)
    {
        self.dateLabel.text = [wallet.compactTimeFormatter stringFromDate:self.transaction.date];
    }
    else
    {
        self.dateLabel.text = [wallet.compactDateFormatter stringFromDate:self.transaction.date];
    }
}

@end