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

@interface MYCBalanceViewController ()

@property(nonatomic) MYCWalletAccount* account;
@property(nonatomic,readonly) MYCWallet* wallet;
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

- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

// Notifications

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.borderHeightConstraint.constant = 1.0/[UIScreen mainScreen].nativeScale;
    [self reloadAccount];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateAllViews];
}

- (void) formattersDidUpdate:(NSNotification*)notif
{
    [self updateAllViews];
}

- (void) walletDidReload:(NSNotification*)notif
{
    [self reloadAccount];
}

- (void) walletExchangeRateDidUpdate:(NSNotification*)notif
{
    [self updateFiatAmount];
    [self updateStatusLabel];
}

- (void) walletDidUpdateNetworkActivity:(NSNotification*)notif
{
    [self updateRefreshControlAnimated:YES];
}

- (void) walletDidUpdateAccount:(NSNotification*)notif
{
    [self reloadAccount];
}

// Update methods

- (void) reloadAccount
{
    [self.wallet inDatabase:^(FMDatabase *db) {
        self.account = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
    }];
}

- (void) setAccount:(MYCWalletAccount *)account
{
    _account = account;
    [self updateAllViews];
}

- (void) updateAllViews
{
    if (!self.isViewLoaded) return;

    MYCWallet* wallet = self.wallet;

    self.btcAmountLabel.text = [wallet.btcFormatter stringFromAmount:self.account.spendableAmount];

    [self updateFiatAmount];
    [self updateRefreshControlAnimated:NO];

    [self.accountButton setTitle:self.account.label ?: @"?" forState:UIControlStateNormal];

    NSString* address = self.account.externalAddress.base58String;
    self.addressLabel.text = address;
    self.qrcodeView.image = [BTCQRCode imageForString:address size:self.qrcodeView.bounds.size scale:[UIScreen mainScreen].scale];

    // Backup button must be visible only when it has > 0 btc and was never backed up.
    self.backupButton.hidden = !(!wallet.isBackedUp && self.account.unconfirmedAmount > 0);

    [self updateStatusLabel];
}

- (void) updateFiatAmount
{
    NSNumber* fiatAmount = [self.wallet.currencyConverter fiatFromBitcoin:self.account.confirmedAmount];
    self.fiatAmountLabel.text = [self.wallet.fiatFormatter stringFromNumber:fiatAmount];
}

- (void) updateStatusLabel
{
    if (self.account.sendingAmount > 0)
    {
        self.statusLabel.text = [NSString stringWithFormat:[NSLocalizedString(@"  Sending %@...", @"") lowercaseString],
                                 [self.wallet.btcFormatter stringFromAmount:self.account.sendingAmount]];
    }
    else if (self.account.receivingAmount > 0)
    {
        self.statusLabel.text = [NSString stringWithFormat:[NSLocalizedString(@"  Receiving %@...", @"") lowercaseString],
                                 [self.wallet.btcFormatter stringFromAmount:self.account.receivingAmount]];
    }
    else
    {
        self.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@: %@", @""),
                                 self.wallet.currencyConverter.marketName,
                                 [self.wallet.fiatFormatter stringFromNumber:self.wallet.currencyConverter.averageRate]];
    }
}

- (void) updateRefreshControlAnimated:(BOOL)animated
{
    [self setRefreshing:self.wallet.isUpdatingAccounts animated:animated];
}

- (void) setRefreshing:(BOOL)refreshing
{
    [self setRefreshing:refreshing animated:NO];
}

- (void) setRefreshing:(BOOL)refreshing animated:(BOOL)animated
{
    _refreshing = refreshing;

    const NSInteger magicTag = 6729571;

    if (self.refreshButton.tag == magicTag)
    {
        return; // will be up to date when animation finishes.
    }

    if (!animated)
    {
        self.refreshButton.hidden = _refreshing;
        self.refreshActivityIndicator.hidden = !_refreshing;
        if (!_refreshing) [self.refreshActivityIndicator stopAnimating];
        if (_refreshing) [self.refreshActivityIndicator startAnimating];
    }
    else
    {
        const CGFloat angle = M_PI;

        if (self.refreshButton.tag != magicTag)
        {
            if (_refreshing)
            {
                [self.refreshActivityIndicator startAnimating];
                self.refreshActivityIndicator.hidden = NO;
                self.refreshActivityIndicator.alpha = 0.0;
                self.refreshButton.transform = CGAffineTransformIdentity;
            }
            else
            {
                self.refreshButton.alpha = 0.0; // stopping refreshing
                self.refreshButton.transform = CGAffineTransformMakeRotation(-angle);
            }
        }

        self.refreshButton.tag = magicTag;

        BOOL valueBeforeAnimation = _refreshing;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.15 animations:^{
                self.refreshActivityIndicator.alpha = _refreshing ? 1.0 : 0.0;
            } completion:^(BOOL finished) {
            }];
        });

        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseIn|UIViewAnimationOptionBeginFromCurrentState animations:^{

            self.refreshButton.alpha = _refreshing ? 0.0 : 1.0;

            if (_refreshing)
            {
                self.refreshButton.transform = CGAffineTransformMakeRotation(angle);
            }
            else
            {
                self.refreshButton.transform = CGAffineTransformMakeRotation(0);
            }

        } completion:^(BOOL finished) {

            if (valueBeforeAnimation == _refreshing)
            {
                if (!_refreshing) [self.refreshActivityIndicator stopAnimating];
                if (_refreshing) [self.refreshActivityIndicator startAnimating];

                self.refreshButton.hidden = _refreshing;
                self.refreshActivityIndicator.hidden = !_refreshing;
                self.refreshActivityIndicator.alpha = 1.0;
                self.refreshButton.alpha = 1.0;

                self.refreshButton.tag = 0;
            }
            else
            {
                [self setRefreshing:_refreshing animated:YES];
            }
        }];
    }
}



// Actions



- (BOOL)canBecomeFirstResponder
{
    // To support UIMenuController.
    return YES;
}

- (void) copy:(id)_
{
    [[UIPasteboard generalPasteboard] setValue:self.addressLabel.text
                             forPasteboardType:(id)kUTTypeUTF8PlainText];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(copy:))
    {
        return YES;
    }
    return NO;
}

- (IBAction) refresh:(id)sender
{
    [self setRefreshing:YES animated:YES];

    [self.wallet updateAccount:self.account force:YES completion:^(BOOL success, NSError *error) {

        if (!success)
        {
            #warning TODO: display an error if failed to connect or something.
        }

        [self.wallet updateExchangeRate:YES completion:^(BOOL success, NSError *error2) {

            //NSLog(@"currency updated: %@", error2);
        }];
    }];
}

- (IBAction)tapAddress:(UILongPressGestureRecognizer*)gr
{
    if (gr.state == UIGestureRecognizerStateBegan)
    {
        [self becomeFirstResponder];
        UIMenuController* menu = [UIMenuController sharedMenuController];
        [menu setTargetRect:CGRectInset(self.addressLabel.bounds, 0, self.addressLabel.bounds.size.height/3.0) inView:self.addressLabel];
        [menu setMenuVisible:YES animated:YES];
    }
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
