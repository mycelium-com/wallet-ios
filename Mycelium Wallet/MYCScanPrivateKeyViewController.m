//
//  MYCScanPrivateKeyViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 30.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCScanPrivateKeyViewController.h"
#import "MYCWallet.h"
#import "MYCBackend.h"
#import "MYCTextFieldLiveFormatter.h"
#import "MYCErrorAnimation.h"
#import "MYCScannerView.h"


@interface MYCScanPrivateKeyViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *headerLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextField *privkeyField;
@property (weak, nonatomic) IBOutlet UIButton *scanButton;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@property(nonatomic) BTCPrivateKeyAddress* privateAddress;
@property(nonatomic) BTCAddress* publicAddress;

@property(nonatomic) int checkingBalance;
@end

@implementation MYCScanPrivateKeyViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Cold Storage Spending", @"");
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

        BTCSatoshi balance = 0;
        for (BTCTransactionOutput* txout in outputs)
        {
            balance += txout.value;
        }

        self.statusLabel.text = [NSString stringWithFormat:@"%@ (%@)",
                                 [self.wallet.btcFormatter stringFromAmount:balance],
                                 [self.wallet.fiatFormatter stringFromNumber:[self.wallet.currencyConverter fiatFromBitcoin:balance]]
                                 ];

        if (self.privateAddress && balance > 0)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{


                [self openSendView];

            });
        }
    }];
}

- (void) openSendView
{

}

- (void) cancel:(id)_
{
    [self.view endEditing:YES];
    if (self.completionBlock) self.completionBlock(NO);
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
