//
//  MYCAccountsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCAccountsViewController.h"

@interface MYCAccountsViewController ()

@end

@implementation MYCAccountsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        //self.tintColor = [UIColor colorWithHue:42.0f/360.0f saturation:1.0f brightness:1.00f alpha:1.0f];
        self.tintColor = [UIColor colorWithHue:333.0f/360.0f saturation:0.79f brightness:1.00f alpha:1.0f];

        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Accounts", @"") image:[UIImage imageNamed:@"TabAccounts"] selectedImage:[UIImage imageNamed:@"TabAccountsSelected"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}


@end
