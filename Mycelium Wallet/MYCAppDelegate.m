//
//  AppDelegate.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCAppDelegate.h"
#import "MYCWelcomeViewController.h"
#import "MYCTabBarController.h"
#import "MYCWallet.h"

@interface MYCAppDelegate ()
@property(nonatomic) MYCWelcomeViewController* welcomeViewController;
@property(nonatomic) MYCTabBarController* mainController;
@end

@implementation MYCAppDelegate

+ (MYCAppDelegate*) sharedInstance
{
    return (MYCAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

#if MYCTESTNET
    [[MYCWallet currentWallet] setTestnetOnce];
#endif

    // Wallet exists - display the main UI.
    if ([[MYCWallet currentWallet] isStored])
    {
        [self displayMainView];
    }
    else
    {
        // Wallet is not yet created - show the welcome view.

        self.welcomeViewController = [[MYCWelcomeViewController alloc] initWithNibName:nil bundle:nil];
        self.window.rootViewController = self.welcomeViewController;

        [self.window makeKeyAndVisible];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(walletDidUpdateNetworkActivity:) name:MYCWalletDidUpdateNetworkActivityNotification object:nil];

    return YES;
}

- (void) displayMainView
{
    if (!self.mainController)
    {
        self.mainController = [[UINib nibWithNibName:@"MYCTabBarController" bundle:nil] instantiateWithOwner:nil options:nil].firstObject;
    }

    if (!self.window)
    {
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    self.window.rootViewController = self.mainController;
    [self.window makeKeyAndVisible];
}

- (void) manageAccounts:(id)sender
{
    [self.mainController manageAccounts:sender];
}

- (void) walletDidUpdateNetworkActivity:(id)notif
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = [MYCWallet currentWallet].isNetworkActive;
}


@end
