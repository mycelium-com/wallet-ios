//
//  MYCAccountViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 15.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCAccountViewController.h"
#import "MYCTransactionsViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "PTableViewSource.h"

#import <MobileCoreServices/UTCoreTypes.h>

@interface MYCAccountViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) PTableViewSource* tableViewSource;
@end

@implementation MYCAccountViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.title = [NSString stringWithFormat:NSLocalizedString(@"Account #%@", @""), @(self.account.accountIndex)];

    // TODO: update this item when label is edited.
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.account.label style:UIBarButtonItemStylePlain target:nil action:NULL];

    [self updateSections];

    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (void) updateSections
{
    self.tableViewSource = [[PTableViewSource alloc] init];

    __typeof(self) __weak weakself = self;

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Label", @"");
        [section item:^(PTableViewSourceItem *item) {
            item.title = self.account.label;
        }];
    }];

    if (!self.account.isCurrent)
    {
        [self.tableViewSource section:^(PTableViewSourceSection *section) {
            section.footerTitle = NSLocalizedString(@"Archived account will not be regularly updated", @"");
            [section item:^(PTableViewSourceItem *item) {
                item.title = NSLocalizedString(@"Make Current", @"");
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                    [weakself makeCurrent];
                };
            }];
        }];
    }

    if (!self.account.isArchived)
    {
        if (self.canArchive)
        {
            [self.tableViewSource section:^(PTableViewSourceSection *section) {
                section.footerTitle = NSLocalizedString(@"Archived account is not kept up to date.", @"");
                [section item:^(PTableViewSourceItem *item) {
                    item.title = NSLocalizedString(@"Archive Account", @"");
                    item.textColor = [UIColor redColor];
                    item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                        [weakself archiveAccount];
                    };
                }];
            }];
        }
    }
    else
    {
        [self.tableViewSource section:^(PTableViewSourceSection *section) {
            section.footerTitle = NSLocalizedString(@"Active account is kept up to date.", @"");
            [section item:^(PTableViewSourceItem *item) {
                item.title = NSLocalizedString(@"Activate Account", @"");
                item.textColor = [UIColor colorWithHue:0.33 saturation:1.0 brightness:0.5 alpha:1.0];
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                    [weakself unarchiveAccount];
                };
            }];
        }];
    }

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Transaction History", @"");
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"View Transactions", @"");
            item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself openTransactions];
            };
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"External Public Key", @"");
        [section item:^(PTableViewSourceItem *item) {
            item.title = self.account.externalKeychain.extendedPublicKey;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself copyPubKeyAtIndexPath:indexPath];
            };
        }];
    }];
    
}

- (void) makeCurrent
{

}

- (void) archiveAccount
{
    
}

- (void) unarchiveAccount
{

}

- (void) openTransactions
{
    MYCTransactionsViewController* vc = [[MYCTransactionsViewController alloc] initWithNibName:nil bundle:nil];
    vc.account = self.account;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void) copyPubKeyAtIndexPath:(NSIndexPath*)ip
{
    CGRect rect = [self.tableView rectForRowAtIndexPath:ip];

    [self becomeFirstResponder];
    UIMenuController* menu = [UIMenuController sharedMenuController];
    [menu setTargetRect:rect inView:self.tableView];
    [menu setMenuVisible:YES animated:YES];
}

- (BOOL)canBecomeFirstResponder
{
    // To support UIMenuController.
    return YES;
}

- (void) copy:(id)_
{
    [[UIPasteboard generalPasteboard] setValue:self.account.externalKeychain.extendedPublicKey
                             forPasteboardType:(id)kUTTypeUTF8PlainText];
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(copy:))
    {
        return YES;
    }
    return NO;
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

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.tableViewSource tableView:tableView heightForRowAtIndexPath:indexPath];
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
