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
#import "MYCCurrenciesViewController.h"
#import "MYCCurrencyFormatter.h"

#import "MYCAppDelegate.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCScanPrivateKeyViewController.h"

@interface MYCBalanceViewController ()

@property(nonatomic) MYCWalletAccount* account;
@property(nonatomic,readonly) MYCWallet* wallet;
@property(nonatomic, getter=isRefreshing) BOOL refreshing;

// IBOutlets
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView* refreshActivityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *primaryAmountLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondaryAmountLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton* accountButton;

@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UIButton *receiveButton;
@property (weak, nonatomic) IBOutlet UIButton *backupButton;

@property (weak, nonatomic) IBOutlet UIButton *currencyButton;

@end

@implementation MYCBalanceViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.tintColor = [UIColor colorWithHue:208.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];

        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Balance", @"") image:[UIImage imageNamed:@"TabBalance"] selectedImage:[UIImage imageNamed:@"TabBalanceSelected"]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidReload:) name:MYCWalletDidReloadNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletExchangeRateDidUpdate:) name:MYCWalletCurrencyDidUpdateNotification object:nil];
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
    //self.borderHeightConstraint.constant = 1.0/[UIScreen mainScreen].nativeScale;

    self.sendButton.backgroundColor = self.tintColor;
    self.receiveButton.backgroundColor = self.tintColor;
    [self.backupButton setTitleColor:self.tintColor forState:UIControlStateNormal];

    [self reloadAccount];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateAllViews];
}

- (void) walletDidReload:(NSNotification*)notif
{
    [self reloadAccount];
}

- (void) walletExchangeRateDidUpdate:(NSNotification*)notif
{
    [self updateAmounts];
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
    __block MYCWalletAccount* acc = nil;
    [self.wallet inDatabase:^(FMDatabase *db) {
        acc = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
    }];
    self.account = acc;
}

- (void) setAccount:(MYCWalletAccount *)account
{
    _account = account;
    [self updateAllViews];
}

- (void) updateAllViews
{
    if (!self.isViewLoaded) return;

    [self updateAmounts];
    [self updateRefreshControlAnimated:NO];

    [self.wallet inDatabase:^(FMDatabase *db) {
        self.accountButton.hidden = ([MYCWalletAccount countAllFromDatabase:db] <= 1);
    }];

    [self.accountButton setTitle:self.account.label ?: @"?" forState:UIControlStateNormal];

//    NSString* address = self.account.externalAddress.base58String;
//    self.addressLabel.text = address;
//    self.qrcodeView.image = [BTCQRCode imageForString:address size:self.qrcodeView.bounds.size scale:[UIScreen mainScreen].scale];

    // Backup button must be visible only when it has > 0 btc and was never backed up.
    self.backupButton.hidden = !(!self.wallet.isBackedUp && self.account.unconfirmedAmount > 0);

    [self updateStatusLabel];
}

- (void) updateAmounts
{
    self.primaryAmountLabel.text = [self.wallet.primaryCurrencyFormatter stringFromAmount:self.account.spendableAmount];
    self.secondaryAmountLabel.text = [self.wallet.secondaryCurrencyFormatter stringFromAmount:self.account.spendableAmount];
}

- (void) updateStatusLabel
{
    NSMutableArray* strings = [NSMutableArray array];

    if (self.account.sendingAmount > 0)
    {
        [strings addObject:[NSString stringWithFormat:[NSLocalizedString(@"Sending %@", @"") self],
                            [self.wallet.primaryCurrencyFormatter stringFromAmount:self.account.sendingAmount]]];

    }

    if (self.account.receivingAmount > 0)
    {
        [strings addObject:[NSString stringWithFormat:[NSLocalizedString(@"Receiving %@", @"") self],
                            [self.wallet.primaryCurrencyFormatter stringFromAmount:self.account.receivingAmount]]];
    }
    
    {
        [strings addObject:[NSString stringWithFormat:NSLocalizedString(@"%@: %@", @""),
                                 NSLocalizedString(@"Exchange rate", @""),
                            [self.wallet.fiatCurrencyFormatter stringFromAmount:BTCCoin]]];
    }

    NSString* text = [strings componentsJoinedByString:@"\n"];

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 7.0;
    paragraphStyle.alignment = NSTextAlignmentCenter;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, text.length)];
    self.statusLabel.attributedText = attributedString;
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

    // I give up, to animate it correctly i need a more proper state machine.
    animated = NO;
    
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

        static int x = 0;
        x++;
        int x2 = x;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (x != x2) return;
            self.refreshButton.tag = 0;
            [self updateRefreshControlAnimated:NO];
        });
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
//    [[UIPasteboard generalPasteboard] setValue:self.addressLabel.text
//                             forPasteboardType:(id)kUTTypeUTF8PlainText];
}

- (IBAction)coldStorage:(id)sender {
    __typeof(self) __weak weakself = self;
    MYCScanPrivateKeyViewController* vc = [[MYCScanPrivateKeyViewController alloc] initWithNibName:nil bundle:nil];
    vc.completionBlock = ^(BOOL finished){
        [weakself dismissViewControllerAnimated:YES completion:nil];
    };
    UINavigationController* navc = [[UINavigationController alloc] initWithRootViewController:vc];
    [weakself presentViewController:navc animated:YES completion:nil];
}


- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(copy:))
    {
        return YES;
    }
    return NO;
}

- (IBAction) showCurrencies:(id)sender
{
    MYCCurrenciesViewController* currenciesVC = [[MYCCurrenciesViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:currenciesVC];
    [self presentViewController:navC animated:YES completion:nil];
}

- (IBAction) refresh:(id)sender
{
    [self setRefreshing:YES animated:YES];

    [self.wallet updateAccount:self.account force:YES completion:^(BOOL success, NSError *error) {

        if (!success)
        {
            UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"")
                                                                        message:NSLocalizedString(@"Can't synchronize the account. Try again later.", @"")
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {}]];
            [self presentViewController:ac animated:YES completion:nil];
        }

        [self.wallet updateExchangeRate:YES completion:^(BOOL success, NSError *error2) {

            //MYCLog(@"currency updated: %@", error2);
        }];
    }];
}

//- (IBAction)tapAddress:(UILongPressGestureRecognizer*)gr
//{
//    if (gr.state == UIGestureRecognizerStateBegan)
//    {
//        [self becomeFirstResponder];
//        UIMenuController* menu = [UIMenuController sharedMenuController];
//        [menu setTargetRect:CGRectInset(self.addressLabel.bounds, 0, self.addressLabel.bounds.size.height/3.0) inView:self.addressLabel];
//        [menu setMenuVisible:YES animated:YES];
//    }
//}

- (IBAction)selectAccount:(id)sender
{
    [[MYCAppDelegate sharedInstance] manageAccounts:sender];
}

- (IBAction) send:(id)sender
{
    MYCSendViewController* vc = [[MYCSendViewController alloc] initWithNibName:nil bundle:nil];
    vc.account = self.account;
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
