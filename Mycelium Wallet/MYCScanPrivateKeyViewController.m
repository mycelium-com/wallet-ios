//
//  MYCScanPrivateKeyViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 30.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCScanPrivateKeyViewController.h"
#import "MYCCurrencyFormatter.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCBackend.h"
#import "MYCTextFieldLiveFormatter.h"
#import "MYCErrorAnimation.h"
#import "MYCScannerView.h"
#import "MYCSendViewController.h"
#import "MYCBackupViewController.h"

@interface MYCScanPrivateKeyViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *headerLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextField *privkeyField;
@property (weak, nonatomic) IBOutlet UIButton *scanButton;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@property(nonatomic) BTCPrivateKeyAddress* privateAddress;
@property(nonatomic) NSArray* unspentOutputs;
@property(nonatomic) BTCAddress* publicAddress;

@property(nonatomic) int checkingBalance;
@property(nonatomic) MYCScannerView* scannerView;
@end

@implementation MYCScanPrivateKeyViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Cold Storage", @"");
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    }
    return self;
}

- (void)viewDidLoad
{
    self.headerLabel.text = NSLocalizedString(@"Enter your private key to spend funds from it.", @"");
    self.descriptionLabel.text = NSLocalizedString(@"You may use a paper backup or a private key slip from an ATM. Only WIF format is supported for now.", @"");

    self.privkeyField.placeholder = NSLocalizedString(@"Private Key", @"");
    [self.scanButton setTitle:NSLocalizedString(@"Scan QR code", @"") forState:UIControlStateNormal];

    self.statusLabel.text = @"";
    [self.spinner stopAnimating];

    [super viewDidLoad];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (![self warnAboutSecretLoss]) {
        [self warnAboutBackupIfNeeded];
    }
}


- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

- (void) updateAddressView
{
    NSString* privkeystring = self.privkeyField.text;
    self.scanButton.hidden = (privkeystring.length > 0);

    self.privkeyField.textColor = [UIColor blackColor];
    [self.privateAddress clear];
    self.privateAddress = nil;
    self.publicAddress = nil;

    if (privkeystring.length > 0)
    {
        // Check if that's the valid address.
        BTCAddress* addr = [BTCAddress addressWithBase58String:privkeystring];
        if (!addr) // parse failure or checksum failure
        {
            // Show in red only when not editing or when it's certainly incorrect.
            if (!self.privkeyField.isFirstResponder || privkeystring.length >= 52)
            {
                self.privkeyField.textColor = [UIColor redColor];
                self.statusLabel.text = NSLocalizedString(@"Key is invalid", @"");
            }
        }
        else if (!!self.wallet.isTestnet != !!addr.isTestnet)
        {
            self.privkeyField.textColor = [UIColor orangeColor];
            self.statusLabel.text = NSLocalizedString(@"Key does not belong to Bitcoin network", @"");
        }
        else if ([addr isKindOfClass:[BTCPrivateKeyAddress class]])
        {
            // valid, should try to update.
            self.privateAddress = (id)addr;
            self.publicAddress = [addr publicAddress];
            [self checkBalance];
        }
        else
        {
            // It's a public key, simply check the amount on that address.
            self.publicAddress = [addr publicAddress];
            [self checkBalance];
        }
    }
}

- (void) checkBalance
{
    if (!self.publicAddress) return;

    self.checkingBalance++;
    int myCounter = self.checkingBalance;

    if (self.privateAddress)
    {
        self.statusLabel.text = NSLocalizedString(@"Loading coins...", @"");
    }
    else
    {
        self.statusLabel.text = NSLocalizedString(@"Checking public address...", @"");
    }

    [self.spinner startAnimating];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        if (!self.publicAddress) return;
        if (myCounter != self.checkingBalance) return;

        [self.wallet.backend loadUnspentOutputsForAddresses:@[ self.publicAddress ] completion:^(NSArray *outputs, NSInteger height, NSError *error) {

            // Another operation was launched, ignore this one.
            if (myCounter != self.checkingBalance) return;

            [self.spinner stopAnimating];

            if (!outputs)
            {
                MYCError(@"Cold Storage: Failed importing coins: %@", error);
                self.statusLabel.text = NSLocalizedString(@"Failed to load coins. Please try again.", @"");
                return;
            }

            BTCAmount balance = 0;
            for (BTCTransactionOutput* txout in outputs)
            {
                balance += txout.value;
            }

            self.unspentOutputs = outputs;

            self.statusLabel.text = [self.wallet.primaryCurrencyFormatter stringFromAmount:balance];

            if (self.privateAddress && balance > 0)
            {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

                    [self openSendView];

                });
            }
        }];
    });
}

- (void) openSendView
{
    MYCSendViewController* vc = [[MYCSendViewController alloc] initWithNibName:nil bundle:nil];
    vc.key = self.privateAddress.key;
    vc.unspentOutputs = self.unspentOutputs;
    vc.changeAddress = self.privateAddress.publicAddress; // send change back to that scanned address
    vc.prefillAllFunds = YES;

    __block MYCWalletAccount* account = nil;
    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        account = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
        vc.defaultAddress = account.internalAddress; // using internal address for better privacy.
        vc.defaultAddressLabel = account.label;
    }];

    __weak __typeof(self) weakself = self;
    vc.completionBlock = ^(BOOL finished) {

        if (finished)
        {
            if (weakself.completionBlock) weakself.completionBlock(finished);
        }
        else
        {
            [weakself.navigationController popViewControllerAnimated:YES];
            [self.navigationController setNavigationBarHidden:NO animated:YES];
        }

        // make sure tx is visible on this account if it received cash.
        [[MYCWallet currentWallet] updateAccount:account force:YES completion:^(BOOL success, NSError *error) {
        }];
    };
    if (vc.key)
    {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void) cancel:(id)_
{
    [self.view endEditing:YES];
    if (self.completionBlock) self.completionBlock(NO);
}

- (IBAction)scanPrivateKey:(id)sender
{
    UIView* targetView = self.navigationController.view;
    CGRect rect = [targetView convertRect:self.privkeyField.bounds fromView:self.privkeyField];

    [MYCScannerView checkPermissionToUseCamera:^(BOOL granted) {

        if (!granted)
        {
            UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Camera Access", @"")
                                                                        message:NSLocalizedString(@"Please allow camera access in system settings.", @"")
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {}]];
            [self presentViewController:ac animated:YES completion:nil];

            return;
        }

        self.scannerView = [MYCScannerView presentFromRect:rect inView:targetView detection:^(NSString *message) {
            BTCAddress* address = [BTCAddress addressWithBase58String:message];

            if (!address)
            {
                self.scannerView.errorMessage = NSLocalizedString(@"Not a valid Bitcoin address or payment request", @"");
                return;
            }

            if (!!address.isTestnet != !!self.wallet.isTestnet)
            {
                self.scannerView.errorMessage = NSLocalizedString(@"Key does not belong to Bitcoin network", @"");
                return;
            }

            if ([address isKindOfClass:[BTCPrivateKeyAddress class]])
            {
                [self.scannerView dismiss];
                self.scannerView = nil;

                self.privkeyField.text = address.base58String;
                [self updateAddressView];
            }
            else
            {
                [self.wallet.backend loadUnspentOutputsForAddresses:@[ address ] completion:^(NSArray *outputs, NSInteger height, NSError *error) {

                    if (!outputs)
                    {
                        return;
                    }

                    BTCAmount balance = 0;
                    for (BTCTransactionOutput* txout in outputs)
                    {
                        balance += txout.value;
                    }

                    NSString* balanceString = [self.wallet.primaryCurrencyFormatter stringFromAmount:balance];
                    
                    self.scannerView.message = [NSString stringWithFormat:NSLocalizedString(@"This is a public address with %@", @""), balanceString];
                }];
            }
        }];
    }];
}

- (BOOL) warnAboutSecretLoss {
    if ([[MYCWallet currentWallet] verifySeedIntegrity]) {
        return NO;
    }

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Wallet may be locked out!", @"")
                                                                   message:NSLocalizedString(@"Do not send any funds to this wallet. Restore wallet from backup or contact Mycelium Support.", @"")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self cancel:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    return YES;
}


- (BOOL) warnAboutBackupIfNeeded {

    if ([MYCWallet currentWallet].isBackedUp) return NO;

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Back up your wallet", @"")
                                                                   message:NSLocalizedString(@"Disabling your passcode, software or hardware failure may render your funds forever inaccessible. This takes only a minute.", @"")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",@"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self cancel:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Back up now", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self backup:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];

    return YES;
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






- (IBAction)didBeginEditingAddress:(id)sender
{
    [self updateAddressView];
}

- (IBAction)didEditAddress:(id)sender
{
    [self updateAddressView];
}

- (IBAction)didEndEditingAddress:(id)sender
{
    [self updateAddressView];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.privkeyField)
    {
        [self.view endEditing:YES];
    }
    return YES;
}



@end
