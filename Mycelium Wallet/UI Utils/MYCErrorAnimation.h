//
//  MYCErrorAnimation.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 13.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCErrorAnimation : CAKeyframeAnimation

// Returns an animation that can be attached to a view.
+ (instancetype) oneShotErrorAnimation:(CGFloat)radius;

// Shake with default radius.
+ (void) animateError:(UIView*)view;

// Shake with a specified radius.
+ (void) animateError:(UIView*)view radius:(CGFloat)radius;

@end
