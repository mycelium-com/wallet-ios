//
//  MYCErrorAnimation.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 13.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCErrorAnimation.h"
#import <QuartzCore/QuartzCore.h>

@implementation MYCErrorAnimation

+ (instancetype) oneShotErrorAnimation:(CGFloat)radius
{
    MYCErrorAnimation *animation = [MYCErrorAnimation animationWithKeyPath:@"transform.translation.x"];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    const CGFloat speed = 20.0 / 0.6;
    animation.duration = radius / speed;
    animation.removedOnCompletion = YES;
    animation.values = @[ @(-radius), @(radius), @(-radius*16.0/20.0), @(radius*16.0/20.0), @(-radius*10.0/20.0), @(radius*10.0/20.0), @(-radius*5.0/20.0), @(radius*5.0/20.0), @(0) ];
    return animation;
}

+ (void) animateError:(UIView *)view
{
    [self animateError:view radius:20.0];
}

+ (void) animateError:(UIView *)view radius:(CGFloat)radius
{
    [view.layer addAnimation:[self oneShotErrorAnimation:radius] forKey:@"MYCErrorAnimation"];
}

@end
