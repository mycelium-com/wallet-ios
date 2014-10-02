//
//  MYCReceiveViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCReceiveViewController : UIViewController

@property(nonatomic,copy) void(^completionBlock)();

@end
