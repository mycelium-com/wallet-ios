//
//  MYCTransactionsViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTransactionsViewController.h"

@interface MYCTransactionsViewController ()

@end

@implementation MYCTransactionsViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        //self.tintColor = [UIColor colorWithHue:193.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];
        self.tintColor = [UIColor colorWithHue:42.0f/360.0f saturation:1.0f brightness:1.0f alpha:1.0f];

        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Transactions", @"") image:[UIImage imageNamed:@"TabTransactions"] selectedImage:[UIImage imageNamed:@"TabTransactionsSelected"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

@end
