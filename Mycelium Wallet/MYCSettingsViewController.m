//
//  MYCSettingsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCSettingsViewController.h"

@interface MYCSettingsViewController ()

@end

@implementation MYCSettingsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.tintColor = [UIColor colorWithHue:130.0f/360.0f saturation:1.0f brightness:0.77f alpha:1.0];

        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", @"") image:[UIImage imageNamed:@"TabSettings"] selectedImage:[UIImage imageNamed:@"TabSettingsSelected"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

@end
