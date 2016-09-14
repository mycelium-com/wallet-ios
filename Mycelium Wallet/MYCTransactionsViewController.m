//
//  MYCTransactionsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCTransaction.h"
#import "MYCTransactionDetails.h"
#import "MYCCurrencyFormatter.h"
#import "MYCRoundedView.h"
#import "MYCCurrenciesViewController.h"

#import "MYCTransactionsViewController.h"
#import "MYCTransactionTableViewCell.h"
#import "MYCTransactionDetailsViewController.h"

@interface MYCTransactionsViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) MYCWalletAccount* currentAccount;

@property(nonatomic) BTCNumberFormatter* btcFormatter;
@property(nonatomic) NSNumberFormatter* fiatFormatter;
@end

@implementation MYCTransactionsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Transactions", @"");
        self.tintColor = [UIColor colorWithHue:208.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];
        
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Transactions", @"") image:[UIImage imageNamed:@"TabTransactions"] selectedImage:[UIImage imageNamed:@"TabTransactionsSelected"]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(formattersDidUpdate:) name:MYCWalletCurrencyDidUpdateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidReload:) name:MYCWalletDidReloadNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidUpdateAccount:) name:MYCWalletDidUpdateAccountNotification object:nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) shouldOverrideTintColor
{
    // Only override tint color if opened in the context of tabbar (no specific account is selected).
    return !_account;
}

- (MYCWalletAccount*) account
{
    return _account ?: _currentAccount;
}



#pragma mark - Wallet Notifications


- (void) formattersDidUpdate:(NSNotification*)notif
{
    [self updateCurrencyButton];
    [self.tableView reloadData];
}

- (void) walletDidReload:(NSNotification*)notif
{
    [self.tableView reloadData];
}

- (void) walletDidUpdateNetworkActivity:(NSNotification*)notif
{
    [self updateRefreshControl];
}

- (void) walletDidUpdateAccount:(NSNotification*)notif
{
    [self.tableView reloadData];
}




- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:@"MYCTransactionTableViewCell" bundle:nil] forCellReuseIdentifier:@"cell"];
}


- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateCurrencyButton];

    // Deselect current row.
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];

    // If no account at all, load currentAccount.
    if (!self.account)
    {
        [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
            self.currentAccount = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
        }];
    }

    // Reload account.
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        if (_currentAccount)
        {
            self.currentAccount = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
        }
        [self.account reloadFromDatabase:db];
    }];

    [self.tableView reloadData];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void) updateRefreshControl
{
}

- (void) updateCurrencyButton
{
    NSString* title = [MYCWallet currentWallet].primaryCurrencyFormatter.currencyCode;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(selectCurrency:)];
}

- (void) selectCurrency:(id)_
{
    MYCCurrenciesViewController* currenciesVC = [[MYCCurrenciesViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:currenciesVC];
    [self presentViewController:navC animated:YES completion:nil];
}


#pragma mark - UITableView


- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    __block NSInteger count = 0;
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        count = [MYCTransaction countTransactionsForAccount:self.account database:db];
    }];
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MYCTransactionTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    __block MYCTransaction* tx = nil;
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        tx = [MYCTransaction loadTransactionAtIndex:indexPath.row account:self.account database:db];
        [tx loadDetailsFromDatabase:db];
    }];
    cell.transaction = tx;

    NSString* amountString = nil;
    if ([MYCWallet currentWallet].primaryCurrencyFormatter.isFiatFormatter &&
        tx.transactionDetails.fiatAmount.length > 0 &&
        tx.transactionDetails.fiatCode.length > 0) {
        amountString = [[MYCWallet currentWallet] reformatString:[tx.transactionDetails.fiatAmount stringByReplacingOccurrencesOfString:@"-" withString:@""] forCurrency:tx.transactionDetails.fiatCode];
    }

    if (!amountString) {
        amountString = [[MYCWallet currentWallet].primaryCurrencyFormatter stringFromAmount:ABS(tx.amountTransferred)];
    }

    if (amountString) {
        if (tx.amountTransferred > 0) {
            amountString = [@"+ " stringByAppendingString:amountString];
        }
        else if (tx.amountTransferred < 0) {
            amountString = [@"– " stringByAppendingString:amountString];
        }
    }
    cell.formattedAmount = amountString ?: @"—";

    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    __block MYCTransaction* tx = nil;
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        tx = [MYCTransaction loadTransactionAtIndex:indexPath.row account:self.account database:db];
        [tx loadDetailsFromDatabase:db];
    }];

    MYCTransactionTableViewCell* cell = (id)[tableView cellForRowAtIndexPath:indexPath];

    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"MYCTransactionDetails" bundle:nil];
    MYCTransactionDetailsViewController* vc = [sb instantiateInitialViewController];
    vc.transaction = tx;
    vc.tintColor = self.tintColor;
    vc.redColor = cell.redColor;
    vc.greenColor = cell.greenColor;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
