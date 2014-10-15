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

    UINavigationController* accountsNVC = [[UINavigationController alloc] initWithRootViewController:self.accountsController];
    UINavigationController* transactionsNVC = [[UINavigationController alloc] initWithRootViewController:self.transactionsController];
    UINavigationController* settingsNVC = [[UINavigationController alloc] initWithRootViewController:self.settingsController];

    self.viewControllers = @[ self.balanceController, accountsNVC, transactionsNVC, settingsNVC ];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

- (void) manageAccounts:(id)sender
{
    self.selectedViewController = self.accountsController.navigationController;
}

@end


@implementation MYCTabViewController

- (void) viewDidLoad
{
    [super viewDidLoad];

    if (self.shouldOverrideTintColor)
    {
        self.view.tintColor = self.tintColor;
    }
}

- (BOOL) shouldOverrideTintColor
{
    return YES;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.shouldOverrideTintColor)
    {
        self.tabBarController.tabBar.tintColor = self.tintColor;
        self.navigationController.navigationBar.tintColor = self.tintColor;
    }
}

@end


