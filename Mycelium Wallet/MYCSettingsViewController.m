//
//  MYCSettingsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCSettingsViewController.h"
#import "MYCCurrencyFormatter.h"
#import "MYCCurrenciesViewController.h"
#import "MYCBackupViewController.h"
#import "MYCScanPrivateKeyViewController.h"
#import "MYCWebViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "PTableViewSource.h"
#import "PColor.h"

@interface MYCSettingsViewController ()<UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) PTableViewSource* tableViewSource;
@end

@implementation MYCSettingsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Settings", @"");
        //self.tintColor = [UIColor colorWithHue:280.0f/360.0f saturation:0.8f brightness:0.97f alpha:1.0];
        //self.tintColor = [UIColor colorWithHue:130.0f/360.0f saturation:1.0f brightness:0.77f alpha:1.0];
        self.tintColor = [UIColor colorWithHue:208.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", @"") image:[UIImage imageNamed:@"TabSettings"] selectedImage:[UIImage imageNamed:@"TabSettingsSelected"]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(formattersDidUpdate:) name:MYCWalletCurrencyDidUpdateNotification object:nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) formattersDidUpdate:(NSNotification*)notif
{
    [self updateSections];
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateSections];
    [self.tableView reloadData];
}

- (BOOL) prefersStatusBarHidden
{
    return NO;
}

- (void) updateSections
{
    __block MYCWalletAccount* currentAccount = nil;
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        currentAccount = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
    }];

    self.tableViewSource = [[PTableViewSource alloc] init];

    __typeof(self) __weak weakself = self;

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Currency", @"");
        section.rowHeight = 52.0;
        section.cellStyle = UITableViewCellStyleValue1;
        section.detailFont = [UIFont systemFontOfSize:15.0];
        section.detailTextColor = [UIColor grayColor];

        BTCAmount amount = currentAccount.confirmedAmount;
        if (amount == 0) amount = 1; // sample amount in case wallet is empty.

        MYCCurrencyFormatter* formatter = [MYCWallet currentWallet].primaryCurrencyFormatter;
        NSString* title = [[NSLocale currentLocale] displayNameForKey:NSLocaleCurrencyCode value:formatter.currencyCode] ?: @"";
        if (title.length == 0) {
            title = formatter.currencyCode;
        }

        if (title.length > 1 && formatter.isFiatFormatter) {
            title = [[[title substringToIndex:1] capitalizedString] stringByAppendingString:[title substringFromIndex:1]];
        }

        NSString* subtitle = [formatter stringFromAmount:amount];

        [section item:^(PTableViewSourceItem *item) {
            item.title = title;
            item.detailTitle = subtitle;
            item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                [weakself showCurrencies:nil];
            };
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Cold Storage", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Import Private Key", @"");
            item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {

                MYCScanPrivateKeyViewController* vc = [[MYCScanPrivateKeyViewController alloc] initWithNibName:nil bundle:nil];
                vc.completionBlock = ^(BOOL finished){
                    [weakself dismissViewControllerAnimated:YES completion:nil];
                };
                UINavigationController* navc = [[UINavigationController alloc] initWithRootViewController:vc];
                [weakself presentViewController:navc animated:YES completion:nil];

            };
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Backup", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Export Wallet Master Key", @"");
            item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {

                MYCBackupViewController* vc = [[MYCBackupViewController alloc] initWithNibName:nil bundle:nil];
                vc.completionBlock = ^(BOOL finished){
                    [weakself dismissViewControllerAnimated:YES completion:nil];
                };
                UINavigationController* navc = [[UINavigationController alloc] initWithRootViewController:vc];
                [weakself presentViewController:navc animated:YES completion:nil];

            };
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {

        section.headerTitle =

        section.headerTitle = NSLocalizedString(@"About", @"");

        section.accessoryType = UITableViewCellAccessoryDisclosureIndicator;


        [section item:^(PTableViewSourceItem *item) {
            item.title = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
            item.detailTitle = [NSString stringWithFormat:NSLocalizedString(@"version %@", @""), [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]];
            item.cellStyle = UITableViewCellStyleValue1;
            item.accessoryType = UITableViewCellAccessoryNone;
            item.detailTextColor = [UIColor grayColor];
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Credits", @"");
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                MYCWebViewController* vc = [[MYCWebViewController alloc] initWithNibName:nil bundle:nil];
                vc.title = NSLocalizedString(@"Credits", @"");
                vc.URL = [[NSBundle mainBundle] URLForResource:@"Credits" withExtension:@"html"];
                [weakself.navigationController pushViewController:vc animated:YES];
            };
        }];
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Legal", @"");
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                MYCWebViewController* vc = [[MYCWebViewController alloc] initWithNibName:nil bundle:nil];
                vc.title = NSLocalizedString(@"Legal", @"");
                vc.URL = [[NSBundle mainBundle] URLForResource:@"Legal" withExtension:@"html"];
                [weakself.navigationController pushViewController:vc animated:YES];
            };

        }];
    }];

#if MYCTESTNET
    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Developer Build", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Use Testnet", @"");
            item.selectionStyle = UITableViewCellSelectionStyleNone;
            item.setupAction =  ^(PTableViewSourceItem* item_, NSIndexPath* indexPath, UITableViewCell* cell) {
                [item_ setupCell:cell atIndexPath:indexPath];
                UISwitch* switchControl = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                switchControl.on = [MYCWallet currentWallet].isTestnet;
                switchControl.onTintColor = self.tintColor;
                [switchControl addTarget:self action:@selector(switchTestnet:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchControl;
            };
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Clear Database", @"");
            item.selectionStyle = UITableViewCellSelectionStyleDefault;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Clear Database?", @"")
                                                                               message:NSLocalizedString(@"History of all transactions will be removed. Master key will be preserved.", @"") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [weakself.tableView deselectRowAtIndexPath:[weakself.tableView indexPathForSelectedRow] animated:NO];
                    [weakself dismissViewControllerAnimated:YES completion:nil];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {

                    // Erase database
                    [[MYCWallet currentWallet] resetDatabase];

                    [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *unlockedWallet) {

                        [[MYCWallet currentWallet] discoverAccounts:unlockedWallet.keychain completion:^(BOOL success, NSError *error) {
                            if (!success)
                            {
                                MYCError(@"MYCWelcomeViewController: failed to discover accounts. Please add them manually. %@", error);
                            }
                            else
                            {
                                [[MYCWallet currentWallet] updateActiveAccounts:^(BOOL success, NSError *error) {
                                }];
                            }
                        }];
                        
                    } reason:NSLocalizedString(@"Authenticate to store master key on the device", @"")];

                    [weakself dismissViewControllerAnimated:YES completion:nil];

                    [[NSNotificationCenter defaultCenter] postNotificationName:MYCWalletDidReloadNotification object:self];
                }]];
                [weakself presentViewController:alert animated:YES completion:nil];
            };
            
        }];

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Reset Wallet", @"");
            item.textColor = [UIColor redColor];
            item.selectionStyle = UITableViewCellSelectionStyleDefault;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Reset Wallet?", @"")
                                                    message:NSLocalizedString(@"Your keys will be wiped out from this device and app will restart with clean state.", @"") preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [weakself.tableView deselectRowAtIndexPath:[weakself.tableView indexPathForSelectedRow] animated:NO];
                    [weakself dismissViewControllerAnimated:YES completion:nil];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {

                    // Remove secrets from the keychain
                    [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *uw) {
                        uw.mnemonic = nil;
                    } reason:NSLocalizedString(@"Authorize removal of the master key", @"")];

                    // Erase database
                    [[MYCWallet currentWallet] removeDatabase];

                    [weakself dismissViewControllerAnimated:YES completion:nil];

                    // Kill the app so we show startup screen as in fresh install.
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        exit(666);
                    });

                }]];
                [weakself presentViewController:alert animated:YES completion:nil];
            };

        }];


    }];
#endif // MYCTESTNET

}

- (IBAction) showCurrencies:(id)sender
{
    MYCCurrenciesViewController* currenciesVC = [[MYCCurrenciesViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:currenciesVC];
    [self presentViewController:navC animated:YES completion:nil];
}


- (void) switchTestnet:(UISwitch*)switchControl
{
    [MYCWallet currentWallet].testnet = switchControl.on;
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
