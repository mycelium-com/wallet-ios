//
//  AppDelegate.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (MYCAppDelegate*) sharedInstance;

// Called when new wallet is created or imported and we can show the main view.
- (void) displayMainView;

// Called from other views to go to accounts view.
- (void) manageAccounts:(id)sender;

@end

