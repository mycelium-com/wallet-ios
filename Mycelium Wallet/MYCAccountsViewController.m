//
//  MYCAccountsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCAccountsViewController.h"
#import "MYCAccountViewController.h"
#import "MYCAccountTableViewCell.h"

#import "MYCWallet.h"
#import "MYCWalletAccount.h"

#import "PTableViewSource.h"

@interface MYCAccountsViewController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic) NSArray* activeAccounts;
@property(nonatomic) NSArray* archivedAccounts;
@property(nonatomic) PTableViewSource* tableViewSource;

@property(nonatomic, weak) IBOutlet UITableView* tableView;

@end

@implementation MYCAccountsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Accounts", @"");
        self.tintColor = [UIColor colorWithHue:13.0f/360.0f saturation:0.79f brightness:1.00f alpha:1.0f];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Accounts", @"") image:[UIImage imageNamed:@"TabAccounts"] selectedImage:[UIImage imageNamed:@"TabAccountsSelected"]];

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                               target:self
                                                                                               action:@selector(addAccount:)];

        [self updateRefreshControl];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(formattersDidUpdate:) name:MYCWalletFormatterDidUpdateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidReload:) name:MYCWalletDidReloadNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletExchangeRateDidUpdate:) name:MYCWalletCurrencyConverterDidUpdateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidUpdateNetworkActivity:) name:MYCWalletDidUpdateNetworkActivityNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidUpdateAccount:) name:MYCWalletDidUpdateAccountNotification object:nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerNib:[UINib nibWithNibName:@"MYCAccountTableViewCell" bundle:nil] forCellReuseIdentifier:@"accountCell"];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateSections];
    [self.tableView reloadData];
}

- (void) updateSections
{
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        NSArray* accs = [MYCWalletAccount loadAccountsFromDatabase:db];
        NSMutableArray* activeAccs = [NSMutableArray array];
        NSMutableArray* archivedAccs = [NSMutableArray array];
        for (MYCWalletAccount* acc in accs)
        {
            if (!acc.isArchived)
            {
                [activeAccs addObject:acc];
            }
            else
            {
                [archivedAccs addObject:acc];
            }
        }
        self.activeAccounts = activeAccs;
        self.archivedAccounts = archivedAccs;
    }];

    self.tableViewSource = [[PTableViewSource alloc] init];

    self.tableViewSource.cellIdentifier = @"accountCell";

    self.tableViewSource.setupAction = ^(PTableViewSourceItem* item, NSIndexPath* indexPath, UITableViewCell* cell) {
        MYCAccountTableViewCell* acccell = (id)cell;
        acccell.account = item.value;
        acccell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    };

    __typeof(self) __weak weakself = self;

    if (self.activeAccounts.count > 0)
    {
        [self.tableViewSource section:^(PTableViewSourceSection *section) {
            section.headerTitle = NSLocalizedString(@"Active", @"");
            for (MYCWalletAccount* acc in self.activeAccounts)
            {
                [section item:^(PTableViewSourceItem *item) {
                    item.value = acc;
                    item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                        [weakself selectAccount:item.value];
                    };
                }];
            }
        }];
    }

    if (self.archivedAccounts.count > 0)
    {
        [self.tableViewSource section:^(PTableViewSourceSection *section) {
            section.headerTitle = NSLocalizedString(@"Archived", @"");
            for (MYCWalletAccount* acc in self.archivedAccounts)
            {
                [section item:^(PTableViewSourceItem *item) {
                    item.value = acc;
                    item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                        [weakself selectAccount:item.value];
                    };
                }];
            }
        }];
    }
}

- (void) updateRefreshControl
{
    if ([MYCWallet currentWallet].isUpdatingAccounts)
    {
        UIActivityIndicatorView* indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:indicator];
        [indicator startAnimating];
    }
    else
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                              target:self
                                                                                              action:@selector(refreshAll:)];
    }
}




#pragma mark - Wallet Notifications




- (void) formattersDidUpdate:(NSNotification*)notif
{
    [self updateSections];
    [self.tableView reloadData];
}

- (void) walletDidReload:(NSNotification*)notif
{
    [self updateSections];
    [self.tableView reloadData];
}

- (void) walletExchangeRateDidUpdate:(NSNotification*)notif
{
    [self.tableView reloadData];
}

- (void) walletDidUpdateNetworkActivity:(NSNotification*)notif
{
    [self updateRefreshControl];
}

- (void) walletDidUpdateAccount:(NSNotification*)notif
{
    //MYCWalletAccount* acc = notif.object;

    // TODO: find which account was updated and reload its cell.

    // For now simply reload all accounts and all cells.
    [self updateSections];
    [self.tableView reloadData];
}





#pragma mark - Actions


- (void) selectAccount:(MYCWalletAccount*)acc
{
    MYCAccountViewController* vc = [[MYCAccountViewController alloc] initWithNibName:nil bundle:nil];
    vc.account = acc;
    vc.canArchive = self.activeAccounts.count > 1;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void) refreshAll:(id)_
{
    // Immediately reload all accounts from disk.
    [self updateSections];
    [self.tableView reloadData];

    // Make requests to synchronize active accounts.
    for (MYCWalletAccount* acc in self.activeAccounts)
    {
        [[MYCWallet currentWallet] updateAccount:acc force:YES completion:^(BOOL success, NSError *error) {
            if (!success)
            {
                // TODO: show error. Make sure to coalesce similar errors in one.
            }
        }];
    }

    // Also synchronize archived accounts, but not more frequent than usual schedule.
    for (MYCWalletAccount* acc in self.archivedAccounts)
    {
        [[MYCWallet currentWallet] updateAccount:acc force:NO completion:^(BOOL success, NSError *error) {
            if (!success)
            {
                // TODO: show error. Make sure to coalesce similar errors in one.
            }
        }];
    }
}

- (void) addAccount:(id)_
{
    // Add another account if the last one is not empty.
    // Show alert if trying to add more.
    // Push the view with account options.
}


#pragma mark - UITableView


- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.tableViewSource numberOfSectionsInTableView:tableView];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.tableViewSource tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView titleForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [self.tableViewSource tableView:tableView titleForFooterInSection:section];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.tableViewSource tableView:tableView willSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableViewSource tableView:tableView didSelectRowAtIndexPath:indexPath];
}

@end
