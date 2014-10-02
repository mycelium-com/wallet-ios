//
//  MYCAccountsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCAccountsViewController.h"
#import "PTableViewSource.h"

@interface MYCAccountsViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) PTableViewSource* tableViewSource;
@end

@implementation MYCAccountsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Accounts", @"");
        self.tintColor = [UIColor colorWithHue:13.0f/360.0f saturation:0.79f brightness:1.00f alpha:1.0f];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Accounts", @"") image:[UIImage imageNamed:@"TabAccounts"] selectedImage:[UIImage imageNamed:@"TabAccountsSelected"]];

        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                               target:self
                                                                                               action:@selector(refreshAll:)];

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                               target:self
                                                                                               action:@selector(addAccount:)];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self updateSections];
}

- (void) updateSections
{
    self.tableViewSource = [[PTableViewSource alloc] init];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Active", @"");
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Main Account", @"");
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Archived", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Alpaca Socks Shop", @"");
        }];
    }];
}

- (void) refreshAll:(id)_
{
    
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


@end
