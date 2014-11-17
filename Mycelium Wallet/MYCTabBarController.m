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

//    [self installSwipe:self.balanceController];
//    [self installSwipe:self.accountsController];
//    [self installSwipe:self.transactionsController];
//    [self installSwipe:self.settingsController];
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

- (void) installSwipe:(UIViewController*)vc
{
    UISwipeGestureRecognizer* gr = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft:)];
    gr.direction = UISwipeGestureRecognizerDirectionLeft;
    [vc.view addGestureRecognizer:gr];

    UISwipeGestureRecognizer* gr2 = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight:)];
    gr2.direction = UISwipeGestureRecognizerDirectionRight;
    [vc.view addGestureRecognizer:gr2];
}

- (void) swipeLeft:(UISwipeGestureRecognizer*)gr
{
    if (self.selectedIndex < (self.viewControllers.count - 1))
    {
        self.selectedIndex = self.selectedIndex + 1;
    }
}

- (void) swipeRight:(UISwipeGestureRecognizer*)gr
{
    if (self.selectedIndex > 0)
    {
        self.selectedIndex = self.selectedIndex - 1;
    }
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


