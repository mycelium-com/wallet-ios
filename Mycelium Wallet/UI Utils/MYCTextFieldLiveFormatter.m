//
//  MYCTextFieldFormatter.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTextFieldLiveFormatter.h"

@interface MYCTextFieldLiveFormatter ()
// All delegate calls are forwarded here first so you can have complete control.
// This property is automatically set to textField.delegate when textField is assigned.
@property(weak, nonatomic) id<UITextFieldDelegate> delegate;

@end

@implementation MYCTextFieldLiveFormatter {
    BOOL _reformatInputField;
}

- (void) setTextField:(UITextField *)textField
{
    [_textField removeTarget:self action:NULL forControlEvents:UIControlEventEditingChanged];
    _textField.delegate = self.delegate; // restore delegate

    _textField = textField;

    self.delegate = _textField.delegate; // preserve delegate before overriding.
    [_textField addTarget:self action:@selector(didEdit:) forControlEvents:UIControlEventEditingChanged];
    _textField.delegate = self;
}

- (void) setFormatter:(NSNumberFormatter *)formatter
{
    _formatter = formatter;
}

- (id) initWithTextField:(UITextField*)textField numberFormatter:(NSNumberFormatter*)formatter
{
    if (self = [super init])
    {
        self.textField = textField;
        self.formatter = formatter;
    }
    return self;
}


#pragma mark - UITextFieldDelegate


- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField        // return NO to disallow editing.
{
    if ([self.delegate respondsToSelector:_cmd]) return [self.delegate textFieldShouldBeginEditing:textField];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField           // became first responder
{
    if ([self.delegate respondsToSelector:_cmd]) [self.delegate textFieldDidBeginEditing:textField];
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField          // return YES to allow editing to stop and to resign first responder status. NO to disallow the editing session to end
{
    if ([self.delegate respondsToSelector:_cmd]) return [self.delegate textFieldShouldEndEditing:textField];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField             // may be called if forced even if shouldEndEditing returns NO (e.g. view removed from window) or endEditing:YES called
{
    if ([self.delegate respondsToSelector:_cmd]) [self.delegate textFieldDidEndEditing:textField];
}

- (BOOL)textFieldShouldClear:(UITextField *)textField               // called when clear button pressed. return NO to ignore (no notifications)
{
   if ([self.delegate respondsToSelector:_cmd]) return [self.delegate textFieldShouldClear:textField];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField              // called when 'return' key pressed. return NO to ignore.
{
    if ([self.delegate respondsToSelector:_cmd]) return [self.delegate textFieldShouldReturn:textField];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if ([self.delegate respondsToSelector:_cmd])
    {
        BOOL r = [self.delegate textField:textField shouldChangeCharactersInRange:range replacementString:string];
        if (!r) return NO;
    }

    _reformatInputField = YES;

    NSNumberFormatter* formatter = self.formatter;
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

        // If entering 0 after decimal separator, do not reformat it.
        if (decimalSepLocation != NSNotFound && [string isEqual:@"0"])
        {
            _reformatInputField = NO;
        }
        else
        {
            _reformatInputField = YES;
        }
    }
    else // some weird copy-pasting - do not break user's input.
    {
        _reformatInputField = NO;
    }

    return YES;
}

- (void) didEdit:(id)sender
{
    if (self.textField.text.length > 0 && _reformatInputField)
    {
        NSNumber* number = [self.formatter numberFromString:self.textField.text];
        self.textField.text = [self.formatter stringFromNumber:number];
    }
}



@end
