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
#import "MYCSendViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"
#import "BTCBitcoinURL.h"

@interface MYCAppDelegate ()
@property(nonatomic) MYCWelcomeViewController* welcomeViewController;
@property(nonatomic) MYCTabBarController* mainController;
@property(nonatomic) NSNumber* previousSystemBrightness;
@end

@implementation MYCAppDelegate

+ (MYCAppDelegate*) sharedInstance
{
    return (MYCAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

#if DEBUG && 0
//  One-shot database removal when the stale schema does not even allow app to start.
#warning DEBUG: RESETTING DATABASE ON LAUNCH
    [[MYCWallet currentWallet] resetDatabase];
    exit(111);
#endif

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

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Handle bitcoin: url if possible.
    BTCBitcoinURL* btcURL = [[BTCBitcoinURL alloc] initWithURL:url];
    if (btcURL && btcURL.address)
    {
        if (self.mainController)
        {
            [self.mainController dismissViewControllerAnimated:YES completion:^{ }];
            MYCSendViewController* vc = [[MYCSendViewController alloc] initWithNibName:nil bundle:nil];

            __block MYCWalletAccount* acc = nil;
            [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
                acc = [MYCWalletAccount loadCurrentAccountFromDatabase:db];
            }];

            vc.account = acc;
            vc.defaultAddress = btcURL.address;
            vc.defaultAmount = btcURL.amount;

            vc.completionBlock = ^(BOOL sent){
                [self.mainController dismissViewControllerAnimated:YES completion:nil];
            };
            
            [self.mainController presentViewController:vc animated:YES completion:nil];
            return YES;
        }
    }
    return NO;
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    self.previousSystemBrightness = @([UIScreen mainScreen].brightness);
    if ([[MYCWallet currentWallet] isStored])
    {
        [[MYCWallet currentWallet] updateActiveAccounts:^(BOOL success, NSError *error) {
            if (!success && error)
            {
                MYCError(@"MYCAppDelegate: Automatic update of active accounts failed: %@", error);
            }
        }];
        [[MYCWallet currentWallet] updateExchangeRate:NO completion:^(BOOL success, NSError *error) {
            if (!success && error)
            {
                MYCError(@"MYCAppDelegate: Automatic update of exchange rate failed: %@", error);
            }
        }];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    if (self.previousSystemBrightness)
    {
        [UIScreen mainScreen].brightness = self.previousSystemBrightness.doubleValue;
    }
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
