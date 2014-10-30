//
//  MYCScanPrivateKeyViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 30.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCScanPrivateKeyViewController : UIViewController

// Called with YES if completed successfully. NO if cancelled.
@property(nonatomic,copy) void(^completionBlock)(BOOL completed);

@end
