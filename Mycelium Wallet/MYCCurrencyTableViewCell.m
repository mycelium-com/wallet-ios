//
//  MYCCurrencyTableViewCell.m
//  Mycelium Wallet
//
//  Created by Pascal Edmond on 09/03/2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCCurrencyTableViewCell.h"
#import "MYCCurrencyFormatter.h"

@interface MYCCurrencyTableViewCell ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *amountLabel;
@end

@implementation MYCCurrencyTableViewCell

- (void) prepareForReuse {
    [super prepareForReuse];
    self.amount = 0;
    self.formatter = nil;
}

- (void) setAmount:(BTCAmount)amount {
    _amount = amount;
    [self update];
}

- (void) setFormatter:(MYCCurrencyFormatter *)formatter {
    _formatter = formatter;
    [self update];
}

- (void) update {
    if (!_formatter) {
        self.nameLabel.text = @"";
        self.amountLabel.text = @"";
        return;
    }

    NSString* title = [[NSLocale currentLocale] displayNameForKey:NSLocaleCurrencyCode value:self.formatter.currencyCode] ?: @"";
    if (title.length == 0) {
        title = self.formatter.currencyCode;
    }
    if (title.length > 1 && self.formatter.isFiatFormatter) {
        title = [[[title substringToIndex:1] capitalizedString] stringByAppendingString:[title substringFromIndex:1]];
    }
    self.nameLabel.text = title;
    self.amountLabel.text = [self.formatter stringFromAmount:_amount ?: 123456789];
}

@end
