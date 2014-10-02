//
//  MYCRoundedView.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCRoundedView.h"
#import <QuartzCore/QuartzCore.h>

@implementation MYCRoundedView

- (void) awakeFromNib
{
    [super awakeFromNib];
    [self setMYCRoundedCorners];
}

- (id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self setMYCRoundedCorners];
    }
    return self;
}

- (void) setMYCRoundedCorners
{
    self.layer.cornerRadius = 3.0;
    self.layer.masksToBounds = YES;
}

@end

