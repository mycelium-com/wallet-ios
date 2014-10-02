//
//  MYCSendViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCSendViewController.h"

@interface MYCSendViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *accountNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@property (weak, nonatomic) IBOutlet UIButton *btcButton;
@property (weak, nonatomic) IBOutlet UIButton *fiatButton;

@property (weak, nonatomic) IBOutlet UITextField *btcField;
@property (weak, nonatomic) IBOutlet UITextField *fiatField;

@property (weak, nonatomic) IBOutlet UILabel *feeLabel;


@property(nonatomic) BOOL fiatInput;

@end

@implementation MYCSendViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Send Bitcoins", @"");
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    [self updateFeeView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.btcField becomeFirstResponder];
}

- (IBAction) cancel:(id)sender
{
    [self complete:NO];
}

- (IBAction) send:(id)sender
{

    [self complete:YES];
}

- (void) complete:(BOOL)sent
{
    [self.btcField resignFirstResponder];
    [self.fiatField resignFirstResponder];
    if (self.completionBlock) self.completionBlock(sent);
    self.completionBlock = nil;
}

- (IBAction)useAllFunds:(id)sender
{


}

- (IBAction)switchToBTC:(id)sender
{
    self.fiatInput = NO;
    [self.btcField becomeFirstResponder];
}

- (IBAction)switchToFiat:(id)sender
{
    self.fiatInput = YES;
    [self.fiatField becomeFirstResponder];
}



#pragma mark - Implementation


- (void) updateFeeView
{
    self.feeLabel.hidden = (self.btcField.text.length == 0);
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
    NSString* newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];

    if (textField == self.btcField)
    {
    }
    else
    {
    }

    return YES;
}

- (IBAction)didBeginEditingBtc:(id)sender
{
    self.fiatInput = NO;
}

- (IBAction)didBeginEditingFiat:(id)sender
{
    self.fiatInput = YES;
}

- (IBAction)didEditBtc:(id)sender
{
    self.fiatField.text = [NSString stringWithFormat:@"%0.2f", 398.0 * self.btcField.text.floatValue / 1000000.0];

    [self updateFeeView];
}

- (IBAction)didEditFiat:(id)sender
{
    self.btcField.text = [NSString stringWithFormat:@"%0.0f", (1000000.0 / 398.0) * self.fiatField.text.floatValue];

    [self updateFeeView];
}



@end
