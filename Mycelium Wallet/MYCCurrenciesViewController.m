//
//  MYCCurrenciesViewController.m
//  Mycelium Wallet
//
//  Created by Pascal Edmond on 09/03/2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCWallet.h"
#import "MYCCurrencyFormatter.h"
#import "MYCCurrenciesViewController.h"
#import "MYCCurrencyTableViewCell.h"

@interface MYCCurrenciesViewController ()

@end

@implementation MYCCurrenciesViewController{
    NSArray* _formatters;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerNib:[UINib nibWithNibName:@"MYCCurrencyTableViewCell" bundle:nil] forCellReuseIdentifier:@"currency"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:self action:@selector(cancel:)];
    self.title = NSLocalizedString(@"Currency", @"");
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_amount == 0) {
        _amount = BTCCoin;
    }
    
    _formatters = [[MYCWallet currentWallet] currencyFormatters];
    
    [self.tableView reloadData];
    [self updateAllFormatters];
}

- (void) updateAllFormatters {
    for (MYCCurrencyFormatter* formatter in _formatters) {
        [[MYCWallet currentWallet] updateCurrencyFormatter:formatter completionHandler:^(BOOL result, NSError *error) {
            [self.tableView reloadData];
        }];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _formatters.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MYCCurrencyTableViewCell* cell = (MYCCurrencyTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"currency" forIndexPath:indexPath];
    cell.amount = _amount;
    cell.formatter = _formatters[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MYCCurrencyFormatter* formatter = _formatters[indexPath.row];
    [[MYCWallet currentWallet] selectPrimaryCurrencyFormatter:formatter];
    [self cancel:self];
}

- (IBAction)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
