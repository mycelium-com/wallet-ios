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

    self.title = NSLocalizedString(@"Account Details", @"");

    [self updateSections];

    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (void) updateSections
{
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.account.label style:UIBarButtonItemStylePlain target:nil action:NULL];

    self.tableViewSource = [[PTableViewSource alloc] init];

    __typeof(self) __weak weakself = self;

    [self.tableViewSource section:^(PTableViewSourceSection *section) {

        section.setupAction = ^(PTableViewSourceItem* item, NSIndexPath* indexPath, UITableViewCell* cell) {
            [item setupCell:cell atIndexPath:indexPath];
            cell.detailTextLabel.textColor = weakself.view.tintColor;
        };

        section.headerTitle = [NSString stringWithFormat:NSLocalizedString(@"Account #%02d", @""), (int)self.account.accountIndex];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Label", @"");
            item.detailTitle = self.account.label;
            item.cellStyle = UITableViewCellStyleValue1;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself editLabel];
                [weakself.tableView deselectRowAtIndexPath:[weakself.tableView indexPathForSelectedRow] animated:YES];
            };
        }];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Public key", @"");
            item.detailTitle = self.account.keychain.extendedPublicKey;
            item.cellStyle = UITableViewCellStyleValue1;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself copyPubKeyAtIndexPath:indexPath];
            };
        }];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"View Transactions", @"");
            item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself openTransactions];
            };
        }];
    }];

    if (!self.account.isCurrent)
    {
        [self.tableViewSource section:^(PTableViewSourceSection *section) {
            section.footerTitle = NSLocalizedString(@"Current account is used to send and receive funds.", @"");
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

    if (!self.account.isCurrent && self.account.spendableAmount == 0)
    {
        [self.tableViewSource section:^(PTableViewSourceSection *section) {
            [section item:^(PTableViewSourceItem *item) {
                item.title = NSLocalizedString(@"Delete Account", @"");
                item.textColor = [UIColor redColor];
                item.selectionStyle = UITableViewCellSelectionStyleDefault;
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Do you really want to delete this account?", @"") message:nil preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                        [weakself.tableView deselectRowAtIndexPath:[weakself.tableView indexPathForSelectedRow] animated:NO];
                        [weakself dismissViewControllerAnimated:YES completion:nil];
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                        [weakself deleteAccount];
                    }]];
                    [weakself presentViewController:alert animated:YES completion:nil];
                };
                
            }];
        }];
    }
}





#pragma mark - Actions



- (void) editLabel
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Account Label", @"")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = self.account.label;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",@"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];

    __typeof(alert) __weak weakalert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.account.label = [weakalert.textFields.firstObject text];
        [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
            [self.account saveInDatabase:db error:NULL];
        }];
        [self updateBackup];
        [self updateSections];
        [self.tableView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:self.account];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) makeCurrent
{
    // If archived, make not archived.
    // If other account is current, unset it.

    [[MYCWallet currentWallet] inTransaction:^(FMDatabase *db, BOOL *rollback) {

        NSError* dberror = nil;
        NSArray* allAccounts = [MYCWalletAccount loadAccountsFromDatabase:db];

        for (MYCWalletAccount* acc in allAccounts)
        {
            if (acc.accountIndex != self.account.accountIndex && acc.isCurrent)
            {
                acc.current = NO;
                if (![acc saveInDatabase:db error:&dberror])
                {
                    MYCError(@"Failed to unset current flag for account %@: %@", @(acc.accountIndex), dberror);
                    *rollback = YES;
                    return;
                }
            }
        }

        self.account.current = YES;
        self.account.archived = NO;

        if (![self.account saveInDatabase:db error:&dberror])
        {
            MYCError(@"Failed to make account %@ current: %@", @(self.account.accountIndex), dberror);
            *rollback = YES;
            return;
        }
    }];

    [self updateBackup];
    [self updateSections];
    [self.tableView reloadData];

    [self.navigationController popViewControllerAnimated:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:self.account];
}

- (void) archiveAccount
{
    // If this account is current, pick another account as a current one.
    // If there is only one non-archived account (this one), do nothing.

    [[MYCWallet currentWallet] inTransaction:^(FMDatabase *db, BOOL *rollback) {

        NSError* dberror = nil;

        // If current, find another account to currentize.
        if (self.account.current)
        {
            NSArray* allAccounts = [MYCWalletAccount loadAccountsFromDatabase:db];

            MYCWalletAccount* anotherAccount = nil;
            for (MYCWalletAccount* acc in allAccounts)
            {
                if (acc.accountIndex != self.account.accountIndex)
                {
                    // Prefer non-archived accounts, but if there are none, use an archived one.
                    if (!anotherAccount || anotherAccount.isArchived)
                    {
                        anotherAccount = acc;
                    }
                }
            }

            if (anotherAccount)
            {
                anotherAccount.current = YES;
                anotherAccount.archived = NO;
                if (![anotherAccount saveInDatabase:db error:&dberror])
                {
                    MYCError(@"Failed to currentize account %@: %@", @(anotherAccount.accountIndex), dberror);
                    *rollback = YES;
                    return;
                }
            }
            else
            {
                MYCError(@"Cannot archive an account when there is no other candidate for archiving");
                *rollback = YES;
                return;
            }
        }

        self.account.current = NO;
        self.account.archived = YES;

        if (![self.account saveInDatabase:db error:&dberror])
        {
            MYCError(@"Failed to archive account %@: %@", @(self.account.accountIndex), dberror);
            *rollback = YES;
            return;
        }
    }];

    [self updateBackup];
    [self updateSections];
    [self.tableView reloadData];

    [self.navigationController popViewControllerAnimated:YES];

    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:self.account];
}

- (void) unarchiveAccount
{
    [[MYCWallet currentWallet] inTransaction:^(FMDatabase *db, BOOL *rollback) {

        self.account.archived = NO;

        NSError* dberror = nil;
        if (![self.account saveInDatabase:db error:&dberror])
        {
            MYCError(@"Failed to unarchive account %@: %@", @(self.account.accountIndex), dberror);
            *rollback = YES;
            return;
        }
    }];

    [self updateBackup];
    [self updateSections];
    [self.tableView reloadData];

    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:self.account];
}

- (void) deleteAccount
{
    // If this account is current, pick another account as a current one.
    // If there is only one non-archived account (this one), do nothing.
    
    [[MYCWallet currentWallet] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        NSError* dberror = nil;
        
        // If current, find another account to currentize.
        if (self.account.current)
        {
            NSArray* allAccounts = [MYCWalletAccount loadAccountsFromDatabase:db];
            
            MYCWalletAccount* anotherAccount = nil;
            for (MYCWalletAccount* acc in allAccounts)
            {
                if (acc.accountIndex != self.account.accountIndex)
                {
                    // Prefer non-archived accounts, but if there are none, use an archived one.
                    if (!anotherAccount || anotherAccount.isArchived)
                    {
                        anotherAccount = acc;
                    }
                }
            }
            
            if (anotherAccount)
            {
                anotherAccount.current = YES;
                anotherAccount.archived = NO;
                if (![anotherAccount saveInDatabase:db error:&dberror])
                {
                    MYCError(@"Failed to currentize account %@: %@", @(anotherAccount.accountIndex), dberror);
                    *rollback = YES;
                    return;
                }
            }
            else
            {
                MYCError(@"Cannot archive an account when there is no other candidate for archiving");
                *rollback = YES;
                return;
            }
        }
        
        if (![self.account deleteFromDatabase:db error:&dberror])
        {
            MYCError(@"Failed to delete account %@: %@", @(self.account.accountIndex), dberror);
            *rollback = YES;
            return;
        }
    }];

    [self updateBackup];
    [self updateSections];
    [self.tableView reloadData];
    
    [self.navigationController popViewControllerAnimated:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidUpdateAccountNotification object:self.account];
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

- (void) updateBackup {
    [[MYCWallet currentWallet] setNeedsBackup];
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
