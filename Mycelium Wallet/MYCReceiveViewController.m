//
//  MYCReceiveViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCReceiveViewController.h"

@interface MYCReceiveViewController ()

@property (weak, nonatomic) IBOutlet UIButton *closeButton;

@property (weak, nonatomic) IBOutlet UIButton *btcButton;
@property (weak, nonatomic) IBOutlet UIButton *fiatButton;

@property (weak, nonatomic) IBOutlet UITextField *btcField;
@property (weak, nonatomic) IBOutlet UITextField *fiatField;

@property (weak, nonatomic) IBOutlet UIView *editingOverlay;

@property(nonatomic) BOOL fiatInput;

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
    self.fiatField.text = [NSString stringWithFormat:@"%0.2f", 398.0 * self.btcField.text.floatValue / 1000000.0];

}

- (IBAction)didEditFiat:(id)sender
{
    self.btcField.text = [NSString stringWithFormat:@"%0.0f", (1000000.0 / 398.0) * self.fiatField.text.floatValue];

}



@end
