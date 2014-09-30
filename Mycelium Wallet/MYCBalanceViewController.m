//
//  MYCBalanceViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBalanceViewController.h"

@interface MYCBalanceViewController ()

@end

@implementation MYCBalanceViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.tintColor = [UIColor colorWithHue:203.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];

        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Balance", @"") image:[UIImage imageNamed:@"TabBalance"] selectedImage:[UIImage imageNamed:@"TabBalanceSelected"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

@end
