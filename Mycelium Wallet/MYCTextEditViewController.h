//
//  MYCTextEditViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCTextEditViewController : UIViewController

@property(nonatomic) NSString* text;
@property(nonatomic, strong) void(^completionHandler)(BOOL result, MYCTextEditViewController* sender);

@end
