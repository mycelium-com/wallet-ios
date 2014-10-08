//
//  MYCRoundedView.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCRoundedView.h"
#import <QuartzCore/QuartzCore.h>

#define MYCRoundingRadius 3.0

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
    self.layer.cornerRadius = MYCRoundingRadius;
    self.layer.masksToBounds = YES;
}

@end

@implementation MYCRoundedButton

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
    self.layer.cornerRadius = MYCRoundingRadius;
    self.layer.masksToBounds = YES;
}

@end

@implementation MYCRoundedTextField

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
    self.layer.cornerRadius = MYCRoundingRadius;
    self.layer.masksToBounds = YES;
}

@end

@implementation MYCRoundedTextView

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
    self.layer.cornerRadius = MYCRoundingRadius;
    self.layer.masksToBounds = YES;
}

@end

