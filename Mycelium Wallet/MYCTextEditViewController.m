//
//  MYCTextEditViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCTextEditViewController.h"
#import "MYCWallet.h"

@interface MYCTextEditViewController ()
@property(nonatomic, weak) IBOutlet UITextView* textView;
@end

@implementation MYCTextEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    self.automaticallyAdjustsScrollViewInsets = NO; // does not work with XIB, so we'll use notifications to update it manually
    self.textView.text = @"";
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.textView.text = self.text;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.textView becomeFirstResponder];
}

- (void) cancel:(id)_ {
    if (self.completionHandler) self.completionHandler(NO, self);
    self.completionHandler = nil;
}

- (void) done:(id)_ {
    self.text = self.textView.text;
    if (self.completionHandler) self.completionHandler(YES, self);
    self.completionHandler = nil;
}

- (void)notifyKeyboardWillShow:(NSNotification *)notification {
    CGRect windowKeyboardFrameEnd = [(NSValue *)[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameEnd = [self.textView convertRect:windowKeyboardFrameEnd fromView:self.view.window];

    CGFloat inset = CGRectIntersection(keyboardFrameEnd, self.textView.bounds).size.height;
    MYCLog(@"MYCTextEditVC: keyboard will show: %@", @(inset));
    self.textView.contentInset = UIEdgeInsetsMake(64, 0, inset, 0);
    self.textView.scrollIndicatorInsets = self.textView.contentInset;

//    [UIView beginAnimations:nil context:NULL];
//    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
//    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue]];
//    [UIView setAnimationBeginsFromCurrentState:YES];
//
//    // <update the view here>
//
//    [self.view setNeedsLayout];
//    [self.view layoutIfNeeded];
//
//    [UIView commitAnimations];
}

- (void)notifyKeyboardWillHide:(NSNotification *)notification {
    MYCLog(@"MYCTextEditVC: keyboard will hide.");
    self.textView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    self.textView.scrollIndicatorInsets = self.textView.contentInset;
}


@end
