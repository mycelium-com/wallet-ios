//
//  MYCTabBarController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTabBarController.h"
#import "MYCBalanceViewController.h"
#import "MYCAccountsViewController.h"
#import "MYCTransactionsViewController.h"
#import "MYCSettingsViewController.h"

@interface MYCTabBarController ()

@end

@implementation MYCTabBarController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [self setup];
    }
    return self;
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (void) setup
{
    self.balanceController      = [[MYCBalanceViewController alloc] initWithNibName:nil bundle:nil];
    self.accountsController     = [[MYCAccountsViewController alloc] initWithNibName:nil bundle:nil];
    self.transactionsController = [[MYCTransactionsViewController alloc] initWithNibName:nil bundle:nil];
    self.settingsController     = [[MYCSettingsViewController alloc] initWithNibName:nil bundle:nil];

    self.viewControllers = @[ self.balanceController, self.accountsController, self.transactionsController, self.settingsController ];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

@end


@implementation MYCTabViewController

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.view.tintColor = self.tintColor;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.tabBarController.tabBar.tintColor = self.tintColor;
}

@end


