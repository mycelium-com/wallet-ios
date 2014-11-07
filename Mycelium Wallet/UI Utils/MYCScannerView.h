//
//  MYCScannerView.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCScannerView : UIView

@property(nonatomic) NSString* errorMessage;
@property(nonatomic) NSString* message;

@property(nonatomic, copy) void(^detectionBlock)(NSString* message);

// Animates the view from a given rect and displays over the entire view.
+ (MYCScannerView*) presentFromRect:(CGRect)rect inView:(UIView*)view detection:(void(^)(NSString* message))detectionBlock;

+ (void) checkPermissionToUseCamera:(void(^)(BOOL granted))completion;

- (void) dismiss;

@end
