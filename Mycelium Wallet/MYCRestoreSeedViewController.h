//
//  MYCRestoreSeedViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 13.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCRestoreSeedViewController : UIViewController
@property(nonatomic, strong) void(^completionBlock)(BOOL restored, UIAlertController* alert);
- (UIAlertController*) notRestoredAlert;
- (UIAlertController*) restoredAlert;

+ (void) promptToRestoreWallet:(NSError *)error in:(UIViewController*)hostVC;
@end
