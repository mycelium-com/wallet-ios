//
//  MYCExchangeRatesViewController.m
//  Mycelium Wallet
//
//  Created by Andrew Toth on 2016-09-26.
//  Copyright © 2016 Mycelium. All rights reserved.
//

#import "MYCExchangeRatesViewController.h"
#import "MYCWallet.h"
#import "MYCExchangeRate.h"
#import "MYCCurrencyFormatter.h"

@interface MYCExchangeRatesViewController ()

@property(nonatomic) NSArray * exchangeRates;
@property(nonatomic) MYCCurrencyFormatter * formatter;

@end

@implementation MYCExchangeRatesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.exchangeRates = [MYCWallet currentWallet].exchangeRates;
    self.formatter = [MYCWallet currentWallet].fiatCurrencyFormatter;
}

- (IBAction)done:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[MYCWallet currentWallet] selectExchangeRate:self.exchangeRates[indexPath.row]];
    [self done:nil];
}

#pragma mark Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.exchangeRates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    MYCExchangeRate * rate = self.exchangeRates[indexPath.row];
    
    cell.textLabel.text = rate.provider;

    self.formatter.currencyConverter.averageRate = rate.price;
    cell.detailTextLabel.text = [self.formatter stringFromAmount:100000000LL];
    
    if ([[MYCWallet currentWallet].exchangeRate.provider isEqualToString:rate.provider]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

@end
