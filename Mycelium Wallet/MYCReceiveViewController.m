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

@property (weak, nonatomic) IBOutlet UIImageView *qrcodeView;
@property (weak, nonatomic) IBOutlet UIButton* accountButton;
@property (weak, nonatomic) IBOutlet UILabel* addressLabel;

@property (weak, nonatomic) IBOutlet UIView *editingOverlay;

@property(nonatomic) BOOL fiatInput;

@end

@implementation MYCReceiveViewController {
    BOOL _reformatInputField;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Receive Bitcoins", @"");
    }
    return self;
}

- (MYCWallet*) wallet
{
    return [MYCWallet currentWallet];
}

- (void) reloadAccount
{
    [self.wallet inDatabase:^(FMDatabase *db) {
        self.account = [MYCWalletAccount currentAccountFromDatabase:db];
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




- (void) viewDidLoad
{
    [super viewDidLoad];
    self.borderHeightConstraint.constant = 1.0/[UIScreen mainScreen].nativeScale;
    [self reloadAccount];
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


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    _reformatInputField = YES;

    NSNumberFormatter* formatter = (textField == self.btcField) ? self.wallet.btcFormatterNaked : self.wallet.fiatFormatterNaked;
    NSString* decimalSep = formatter.decimalSeparator;
    NSUInteger decimalSepLocation = decimalSep.length > 0 ? [textField.text rangeOfString:decimalSep].location : NSNotFound;

    // Allow entering one decimal separator
    if ([string isEqualToString:decimalSep])
    {
        // if no decimal separator there yet, allow one.
        if (decimalSepLocation == NSNotFound)
        {
            _reformatInputField = NO;
        }
        else
        {
            // One more decimal separator would zero the entire thing, disallow that.
            return NO;
        }
    }
    else if ([string isEqual:@""] && range.length > 0) // deleting.
    {
        // If deleting after decimal separator, disallow formatting.
        // Also disallow reformatting if deleting in the middle of the text to avoid cursor reset.
        if ((decimalSepLocation != NSNotFound && range.location >= decimalSepLocation) ||
            range.location != (textField.text.length - 1))
        {
            _reformatInputField = NO;
        }
    }
    else if (string.length == 1 && range.length == 0 && range.location == textField.text.length) // entering one more number in the end
    {
        // Do not allow to enter more fractional digits than required by the number formatter.
        if (decimalSepLocation != NSNotFound && (textField.text.length - 1 - decimalSepLocation) >= formatter.maximumFractionDigits)
        {
            return NO;
        }
        _reformatInputField = YES;
    }
    else // some weird copy-pasting - do not break user's input.
    {
        _reformatInputField = NO;
    }

    return YES;
}

- (IBAction)switchToBTC:(id)sender
{
    self.fiatInput = !self.fiatInput;
    if (self.fiatInput) [self.fiatField becomeFirstResponder];
    else [self.btcField becomeFirstResponder];
}

- (IBAction)switchToFiat:(id)sender
{
    [self switchToBTC:sender];
}

- (IBAction)didBeginEditingBtc:(id)sender
{
    self.fiatInput = NO;
    [self setEditing:YES animated:YES];
}

- (IBAction)didBeginEditingFiat:(id)sender
{
    self.fiatInput = YES;
    [self setEditing:YES animated:YES];
}

- (IBAction)didEditBtc:(id)sender
{
    NSNumber* num = [self.wallet.btcFormatter numberFromString:self.btcField.text];
    self.requestedAmount = [self.wallet.btcFormatter amountFromString:self.btcField.text];
    self.fiatField.text = [self.wallet.fiatFormatterNaked
                           stringFromNumber:[self.wallet.currencyConverter fiatFromBitcoin:self.requestedAmount]];

    if (self.btcField.text.length == 0)
    {
        self.fiatField.text = @"";
    }
    else if (_reformatInputField)
    {
        //self.btcField.text = [self.wallet.btcFormatterNaked stringFromAmount:self.requestedAmount];
        self.btcField.text = [self.wallet.btcFormatterNaked stringFromNumber:num];
    }
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
    else if (_reformatInputField)
    {
        self.fiatField.text = [self.wallet.fiatFormatterNaked stringFromNumber:fiatAmount];
    }
}



@end
