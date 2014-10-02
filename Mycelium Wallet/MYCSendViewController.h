//
//  MYCSendViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCSendViewController : UIViewController

// Called when user cancels or sends money.
@property(nonatomic,copy) void(^completionBlock)(BOOL sent);

@end
