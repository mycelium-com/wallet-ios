//
//  MYCTextEditViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCTextEditViewController.h"

@interface MYCTextEditViewController ()
@property(nonatomic, weak) IBOutlet UITextView* textView;
@end

@implementation MYCTextEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = YES;
    self.textView.text = @"";
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.textView.text = self.text;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    [self.textView becomeFirstResponder];
}

//- (BOOL) automaticallyAdjustsScrollViewInsets {
//#warning TODO: this does not adjust insets of a textview.
//    return YES;
//}

- (void) cancel:(id)_ {
    if (self.completionHandler) self.completionHandler(NO, self);
    self.completionHandler = nil;
}

- (void) done:(id)_ {
    self.text = self.textView.text;
    if (self.completionHandler) self.completionHandler(YES, self);
    self.completionHandler = nil;
}


@end
