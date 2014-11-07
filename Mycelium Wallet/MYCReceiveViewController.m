//
//  MYCReceiveViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCReceiveViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "MYCTextFieldLiveFormatter.h"

@interface MYCReceiveViewController ()

@property(nonatomic,readonly) MYCWallet* wallet;
@property(nonatomic) MYCWalletAccount* account;
@property(nonatomic) BTCSatoshi requestedAmount;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *borderHeightConstraint;

@property (weak, nonatomic) IBOutlet UIButton *closeButton;

@property (weak, nonatomic) IBOutlet UIButton *btcButton;
@property (weak, nonatomic) IBOutlet UIButton *fiatButton;

@property (weak, nonatomic) IBOutlet UITextField *btcField;
@property (weak, nonatomic) IBOutlet UITextField *fiatField;

@property (nonatomic) MYCTextFieldLiveFormatter* btcLiveFormatter;
@property (nonatomic) MYCTextFieldLiveFormatter* fiatLiveFormatter;

@property (weak, nonatomic) IBOutlet UIImageView *qrcodeView;
@property (weak, nonatomic) IBOutlet UIButton* accountButton;
@property (weak, nonatomic) IBOutlet UILabel* addressLabel;

@property (weak, nonatomic) IBOutlet UIView *editingOverlay;

@property(nonatomic) BOOL fiatInput;

@property(nonatomic) NSNumber* previousBrightness;

@end

@implementation MYCReceiveViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Receive Bitcoins", @"");
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.btcLiveFormatter = [[MYCTextFieldLiveFormatter alloc] initWithTextField:self.btcField numberFormatter:self.wallet.btcFormatterNaked];
    self.fiatLiveFormatter = [[MYCTextFieldLiveFormatter alloc] initWithTextField:self.fiatField numberFormatter:self.wallet.fiatFormatterNaked];

    self.borderHeightConstraint.constant = 1.0/[UIScreen mainScreen].nativeScale;

    self.fiatInput = ([MYCWallet currentWallet].preferredCurrency == MYCWalletPreferredCurrencyFiat);

    [self reloadAccount];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self restoreBrightness];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.fiatInput) [self.fiatField becomeFirstResponder];
    else [self.btcField becomeFirstResponder];
}


- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

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

- (void) setRequestedAmount:(BTCSatoshi)requestedAmount
{
    _requestedAmount = requestedAmount;
    [self updateAllViews];
}

- (void) updateAllViews
{
    if (!self.isViewLoaded) return;

    [self.accountButton setTitle:self.account.label ?: @"?" forState:UIControlStateNormal];

    NSString* address = self.account.externalAddress.base58String;
    self.addressLabel.text = address;

    NSString* qrString = address;

    if (self.requestedAmount > 0)
    {
        NSURL* url = [BTCBitcoinURL URLWithAddress:self.account.externalAddress amount:self.requestedAmount label:nil];
        qrString = [url absoluteString];
    }

    self.qrcodeView.image = [BTCQRCode imageForString:qrString
                                                 size:self.qrcodeView.bounds.size
                                                scale:[UIScreen mainScreen].scale];

    [self updateUnits];
}

- (void) updateUnits
{
    [self.btcButton setTitle:self.wallet.btcFormatter.standaloneSymbol forState:UIControlStateNormal];
    [self.fiatButton setTitle:self.wallet.fiatFormatter.currencySymbol forState:UIControlStateNormal];

    self.btcField.placeholder = self.wallet.btcFormatter.placeholderText;
}





- (IBAction)close:(id)sender
{
    [self setEditing:NO animated:YES];
    if (self.completionBlock) self.completionBlock();
    self.completionBlock = nil;
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
    BOOL wasEditing = self.editing;

    [super setEditing:editing animated:animated];

    if (wasEditing == editing) return;

    if (self.isEditing)
    {
        if (!self.btcField.isFirstResponder &&
            !self.fiatField.isFirstResponder)
        {
            [self.btcField becomeFirstResponder];
        }
        if (animated)
        {
            self.editingOverlay.hidden = NO;
            self.editingOverlay.alpha = 0.0;
            [UIView animateWithDuration:0.5 animations:^{
                self.editingOverlay.alpha = 1.0;
            } completion:^(BOOL finished) {
            }];
        }
        else
        {
            self.editingOverlay.hidden = NO;
            self.editingOverlay.alpha = 1.0;
        }
    }
    else
    {
        [self.btcField resignFirstResponder];
        [self.fiatField resignFirstResponder];

        if (animated)
        {
            [UIView animateWithDuration:0.25 animations:^{
                self.editingOverlay.alpha = 0.0;
            } completion:^(BOOL finished) {
                self.editingOverlay.alpha = 1.0;
                self.editingOverlay.hidden = YES;
            }];
        }
        else
        {
            self.editingOverlay.hidden = YES;
        }
    }
}

- (IBAction)editingOverlayTap:(id)sender
{
    [self setEditing:NO animated:YES];
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

- (IBAction)tapQRCode:(id)sender
{
    if (!self.previousBrightness)
    {
        self.previousBrightness = @([UIScreen mainScreen].brightness);
    }

    // If too low, restore brightness.
    if (([UIScreen mainScreen].brightness / self.previousBrightness.doubleValue) <= 0.251)
    {
        [UIScreen mainScreen].brightness = self.previousBrightness.doubleValue;
        self.previousBrightness = nil;
    }
    else
    {
        [UIScreen mainScreen].brightness = 0.5 * [UIScreen mainScreen].brightness;
    }
}

- (void) restoreBrightness
{
    if (self.previousBrightness)
    {
        [UIScreen mainScreen].brightness = self.previousBrightness.doubleValue;
        self.previousBrightness = nil;
    }
}

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


- (void) setFiatInput:(BOOL)fiatInput
{
    if (_fiatInput == fiatInput) return;

    _fiatInput = fiatInput;

    [MYCWallet currentWallet].preferredCurrency = _fiatInput ? MYCWalletPreferredCurrencyFiat : MYCWalletPreferredCurrencyBTC;

    // Exchange fonts

    UIFont* btcFieldFont = self.btcField.font;
    UIFont* fiatFieldFont = self.fiatField.font;

    self.btcField.font = fiatFieldFont;
    self.fiatField.font = btcFieldFont;

    UIFont* btcButtonFont = self.btcButton.titleLabel.font;
    UIFont* fiatButtonFont = self.fiatButton.titleLabel.font;

    self.btcButton.titleLabel.font = fiatButtonFont;
    self.fiatButton.titleLabel.font = btcButtonFont;
}


- (IBAction)switchToBTC:(id)sender
{
    self.fiatInput = !self.fiatInput;
    if (self.fiatInput) [self.fiatField becomeFirstResponder];
    else [self.btcField becomeFirstResponder];

    [self restoreBrightness];
}

- (IBAction)switchToFiat:(id)sender
{
    [self switchToBTC:sender];
}

- (IBAction)didBeginEditingBtc:(id)sender
{
    self.fiatInput = NO;
    [self setEditing:YES animated:YES];
    [self restoreBrightness];
}

- (IBAction)didBeginEditingFiat:(id)sender
{
    self.fiatInput = YES;
    [self setEditing:YES animated:YES];
    [self restoreBrightness];
}

- (IBAction)didEditBtc:(id)sender
{
    self.requestedAmount = [self.wallet.btcFormatter amountFromString:self.btcField.text];
    self.fiatField.text = [self.wallet.fiatFormatterNaked
                           stringFromNumber:[self.wallet.currencyConverter fiatFromBitcoin:self.requestedAmount]];

    if (self.btcField.text.length == 0)
    {
        self.fiatField.text = @"";
    }
    [self restoreBrightness];
}

- (IBAction)didEditFiat:(id)sender
{
    NSNumber* fiatAmount = [self.wallet.fiatFormatter numberFromString:self.fiatField.text];
    self.requestedAmount = [self.wallet.currencyConverter bitcoinFromFiat:[NSDecimalNumber decimalNumberWithDecimal:fiatAmount.decimalValue]];
    self.btcField.text = [self.wallet.btcFormatterNaked stringFromAmount:self.requestedAmount];

    if (self.fiatField.text.length == 0)
    {
        self.btcField.text = @"";
    }
    [self restoreBrightness];
}



@end
