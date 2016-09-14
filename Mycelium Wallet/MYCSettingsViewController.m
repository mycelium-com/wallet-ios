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
#import "MYCTransaction.h"
#import "MYCRestoreSeedViewController.h"
#import "PTableViewSource.h"
#import "PColor.h"

@interface MYCSettingsViewController ()<UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, weak) IBOutlet UITableView* tableView;
@property(nonatomic) PTableViewSource* tableViewSource;
@property(nonatomic) BOOL isWalletOkay;
@end

@implementation MYCSettingsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Settings", @"");
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

    self.isWalletOkay = self.isWalletOkay ?: [[MYCWallet currentWallet] verifySeedIntegrity];

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

        BTCAmount amount = currentAccount.spendableAmount;
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
        section.headerTitle = NSLocalizedString(@"Invite", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Invite a friend", @"");
            item.accessoryType = UITableViewCellAccessoryNone;
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {

                [weakself.tableView deselectRowAtIndexPath:[weakself.tableView indexPathForSelectedRow] animated:NO];

                NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
                NSURL* itunesURL = [NSURL URLWithString:@"https://itunes.apple.com/us/app/mycelium-bitcoin-wallet/id943912290?mt=8"];

                NSArray* items = @[[NSString stringWithFormat:NSLocalizedString(@"Hey, install %@ and I will send you some bitcoins.", @""), appName], itunesURL];
                UIActivityViewController* activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
                activityController.excludedActivityTypes = @[];
                [self presentViewController:activityController animated:YES completion:nil];

            };
        }];
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {
        section.headerTitle = NSLocalizedString(@"Backup", @"");

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Back up the wallet", @"");
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

        if (!self.isWalletOkay) {

            [section item:^(PTableViewSourceItem *item) {
                item.title = NSLocalizedString(@"Restore wallet from backup", @"");
                item.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {

                    MYCRestoreSeedViewController* vb = [[MYCRestoreSeedViewController alloc] initWithNibName:nil bundle:nil];

                    vb.completionBlock = ^(BOOL restored, UIAlertController* alert) {
                        [weakself dismissViewControllerAnimated:YES completion:nil];
                        [weakself presentViewController:alert animated:YES completion:nil];
                    };

                    UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:vb];
                    [weakself presentViewController:navC animated:YES completion:nil];
                };
            }];
        }
    }];

    [self.tableViewSource section:^(PTableViewSourceSection *section) {

        section.headerTitle = NSLocalizedString(@"About", @"");

        section.accessoryType = UITableViewCellAccessoryDisclosureIndicator;


        [section item:^(PTableViewSourceItem *item) {
            item.title = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
            item.detailTitle = [NSString stringWithFormat:NSLocalizedString(@"v%@", @""), [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]];
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

#if 1
    #if 0
        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Diagnostics Log", @"");
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {

                MYCLog(@"MYCSettings: [MYCWallet isPasscodeSet]: %@", @([MYCUnlockedWallet isPasscodeSet]));
                MYCLog(@"MYCSettings: device passcode enabled: %@", @([[MYCWallet currentWallet] isDevicePasscodeEnabled]));
                MYCLog(@"MYCSettings: device TouchID enabled: %@", @([[MYCWallet currentWallet] isTouchIDEnabled]));

                MYCWebViewController* vc = [[MYCWebViewController alloc] initWithNibName:nil bundle:nil];
                vc.title = NSLocalizedString(@"Diagnostical Log", @"");
                vc.text = [MYCWallet currentWallet].diagnosticsLog;
                vc.allowShare = YES;
                [weakself.navigationController pushViewController:vc animated:YES];
            };
        }];
    #endif

        BTCKey* mycpubkey = [[BTCKey alloc] initWithPublicKey:BTCDataFromHex(@"023b127259858902971a997230181c95ffed3f9b5df0046472f3632fc2fa646edc")];

        [section item:^(PTableViewSourceItem *item) {
            item.title = NSLocalizedString(@"Export Diagnostical Data", @"");
            item.action = ^(PTableViewSourceItem* item, NSIndexPath* indexPath) {

                MYCWebViewController* vc = [[MYCWebViewController alloc] initWithNibName:nil bundle:nil];
                vc.title = NSLocalizedString(@"About Diagnostics", @"");
                vc.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:NULL];
                vc.html = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"MYCRecoveryInfo0415" withExtension:@"html"] encoding:NSUTF8StringEncoding error:NULL];
                vc.shouldHandleRequest = ^(MYCWebViewController* wvc, NSURLRequest* req, UIWebViewNavigationType navtype) {
                    if ([req.URL.absoluteString containsString:@"continue-diagnostics-export"]) {

                        MYCLog(@"MYCSettings: [MYCWallet isPasscodeSet]: %@", @([MYCUnlockedWallet isPasscodeSet]));
                        MYCLog(@"MYCSettings: device passcode enabled: %@", @([[MYCWallet currentWallet] isDevicePasscodeEnabled]));
                        MYCLog(@"MYCSettings: device TouchID enabled: %@", @([[MYCWallet currentWallet] isTouchIDEnabled]));
                        MYCLog(@"MYCSettings: device model: %@ (%@)", [UIDevice currentDevice].model, [UIDevice currentDevice].localizedModel);
                        MYCLog(@"MYCSettings: device OS: %@ %@", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion);

                        [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *uw) {
                            BTCMnemonic* mn = uw.mnemonic;
                            if (mn) {
                                MYCLog(@"MYCSettings: mnemonic test error: 0x04");
                            } else {
                                MYCLog(@"MYCSettings: mnemonic test error: %@", uw.error);
                            }
                        } reason:@"Performing diagnostics"];

                        // 1. Prepare data for export.

                        NSString* logString = [NSString stringWithFormat:@"------MYCELIUM DIAGNOSTICS LOG------\n%@", [MYCWallet currentWallet].diagnosticsLog];
                        NSData* db = [[MYCWallet currentWallet] exportDatabaseData];
                        NSData* dbHash = BTCSHA256(db);
                        NSString* dbString = [NSString stringWithFormat:@"------MYCELIUM DATABASE------\n%@\n------END DIAGNOSTICS------",
                                              [db base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed]
                                              ];
                        NSString* ptString = [NSString stringWithFormat:@"%@\n%@", logString, dbString];
                        NSData* plaintext = [ptString dataUsingEncoding:NSUTF8StringEncoding];

                        NSData* sha2 = BTCSHA256(plaintext);

                        NSString* outputData = [NSString stringWithFormat:@"------BEGIN DIAGNOSTICS------\nDB SHA-2: %@\nSHA-2: %@\nMycelium ECIES key: %@\n%@",
                                                BTCHexFromData(dbHash),
                                                BTCHexFromData(sha2),
                                                BTCHexFromData(mycpubkey.publicKey),
                                                ptString
                                                ];

                        // 2. Push the next view.
                        
                        MYCWebViewController* vc2 = [[MYCWebViewController alloc] initWithNibName:nil bundle:nil];
                        vc2.title = NSLocalizedString(@"Export Diagnostics", @"");
                        vc2.text = outputData;
                        vc2.allowShare = YES;

                        // 3. Encrypt and share when "export" button is clicked.
                        vc2.itemsToShare = ^(MYCWebViewController* vwc2) {

                            NSData* dataToEncrypt = [outputData dataUsingEncoding:NSUTF8StringEncoding];

                            BTCEncryptedMessage* ecies = [[BTCEncryptedMessage alloc] init];

                            ecies.senderKey = [[BTCKey alloc] initWithPrivateKey:BTCHash256(dataToEncrypt)];
                            ecies.recipientKey = mycpubkey;
                            NSData* ct = [ecies encrypt:dataToEncrypt];

                            NSString* result = [ct base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed];

                            return @[ result ];
                        };

                        [wvc.navigationController pushViewController:vc2 animated:YES];

                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

                            //[[[UIAlertView alloc] initWithTitle:@"Send to Mycelium" message:@"Send the exported data" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                            UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please send data to Mycelium", @"")
                                                                                              message:NSLocalizedString(@"Use email ios@mycelium.com or Telegram @mycelium.", @"")
                                                                                       preferredStyle:UIAlertControllerStyleAlert];
                            [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                            }]];
                            [alert addAction:[UIAlertAction actionWithTitle:@"Send..." style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                [(id)vc2 share:nil];
                            }]];
                            [vc2 presentViewController:alert animated:YES completion:nil];

                        });

                        return YES;
                    }
                    return NO;
                };
                [weakself.navigationController pushViewController:vc animated:YES];
            };
        }];

#endif

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
