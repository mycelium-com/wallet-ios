//
//  MYCBalanceViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBalanceViewController.h"
#import "MYCSendViewController.h"
#import "MYCReceiveViewController.h"
#import "MYCBackupViewController.h"

#import "MYCAppDelegate.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "BTCQRCode.h"

@interface MYCBalanceViewController ()

@property (nonatomic) MYCWalletAccount* account;
@property(nonatomic, getter=isRefreshing) BOOL refreshing;

// IBOutlets
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView* refreshActivityIndicator;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *borderHeightConstraint;
@property (weak, nonatomic) IBOutlet UILabel *btcAmountLabel;
@property (weak, nonatomic) IBOutlet UILabel *fiatAmountLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIImageView *qrcodeView;
@property (weak, nonatomic) IBOutlet UIButton* accountButton;
@property (weak, nonatomic) IBOutlet UILabel* addressLabel;

@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UIButton *receiveButton;
@property (weak, nonatomic) IBOutlet UIButton *backupButton;

@end

@implementation MYCBalanceViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.tintColor = [UIColor colorWithHue:208.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];

        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Balance", @"") image:[UIImage imageNamed:@"TabBalance"] selectedImage:[UIImage imageNamed:@"TabBalanceSelected"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.borderHeightConstraint.constant = 1.0/[UIScreen mainScreen].nativeScale;

    [self reloadAccount];
}

- (void) reloadAccount
{
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        self.account = [[MYCWallet currentWallet] currentAccountFromDatabase:db];
    }];
}

- (void) setAccount:(MYCWalletAccount *)account
{
    _account = account;
    [self updateAccountInfo];
}

- (void) updateAccountInfo
{
    [self.accountButton setTitle:self.account.label ?: @"?" forState:UIControlStateNormal];

    NSString* address = self.account.externalAddress.base58String;

    self.addressLabel.text = address;

    self.qrcodeView.image = [BTCQRCode imageForString:address size:self.qrcodeView.bounds.size scale:[UIScreen mainScreen].scale];
}

- (void) setRefreshing:(BOOL)refreshing
{
    _refreshing = refreshing;
    self.refreshButton.hidden = _refreshing;
    self.refreshActivityIndicator.hidden = !_refreshing;
    if (_refreshing) [self.refreshActivityIndicator startAnimating];
}

- (IBAction) refresh:(id)sender
{
    self.refreshing = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.refreshing = NO;
    });
}

- (IBAction)selectAccount:(id)sender
{
    [[MYCAppDelegate sharedInstance] manageAccounts:sender];
}

- (IBAction) send:(id)sender
{
    MYCSendViewController* vc = [[MYCSendViewController alloc] initWithNibName:nil bundle:nil];
    vc.completionBlock = ^(BOOL sent){
        [self dismissViewControllerAnimated:YES completion:nil];
    };

    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction) receive:(id)sender
{
    MYCReceiveViewController* vc = [[MYCReceiveViewController alloc] initWithNibName:nil bundle:nil];
    vc.completionBlock = ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    };

    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction) backup:(id)sender
{
    MYCBackupViewController* vc = [[MYCBackupViewController alloc] initWithNibName:nil bundle:nil];
    vc.completionBlock = ^(BOOL finished){
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    UINavigationController* navc = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:navc animated:YES completion:nil];
}


- (void) dismissBackupView:(id)_
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
