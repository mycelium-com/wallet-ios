//
//  MYCWelcomeViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWelcomeViewController.h"
#import "MYCAppDelegate.h"

@interface MYCWelcomeViewController ()
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UILabel *welcomeMessageLabel;
@property (weak, nonatomic) IBOutlet UIButton *createWalletButton;
@property (weak, nonatomic) IBOutlet UIButton *restoreButton;

@property (strong, nonatomic) IBOutlet UIView *generatingWalletView;
@property (weak, nonatomic) IBOutlet UILabel *generatingLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *generatingProgressView;

@end

@implementation MYCWelcomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

- (IBAction)createNewWallet:(id)sender
{
    self.generatingWalletView.frame = self.containerView.bounds;
    self.generatingWalletView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.generatingWalletView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.generatingWalletView];

    self.generatingProgressView.progress = 0.0;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.generatingProgressView setProgress:1.0 animated:YES];
    });

#warning DEBUG: showing full view.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        [[MYCAppDelegate sharedInstance] displayMainView];
        
    });
}

- (IBAction)restoreFromBackup:(id)sender
{

}


@end
