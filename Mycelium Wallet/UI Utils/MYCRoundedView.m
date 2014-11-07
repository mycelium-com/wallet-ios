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

- (void) setBorderRadius:(CGFloat)borderRadius
{
    _borderRadius = borderRadius;
    self.layer.cornerRadius = _borderRadius;
}

- (void) setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    self.layer.borderColor = _borderColor.CGColor;
}

- (void) setBorderWidth:(CGFloat)borderWidth
{
    _borderWidth = borderWidth;
    self.layer.borderWidth = _borderWidth;
}

- (void) setMYCRoundedCorners
{
    self.borderRadius = MYCRoundingDefaultRadius;
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

- (void) setBorderRadius:(CGFloat)borderRadius
{
    _borderRadius = borderRadius;
    self.layer.cornerRadius = _borderRadius;
}

- (void) setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    self.layer.borderColor = _borderColor.CGColor;
}

- (void) setBorderWidth:(CGFloat)borderWidth
{
    _borderWidth = borderWidth;
    self.layer.borderWidth = _borderWidth;
}

- (void) setMYCRoundedCorners
{
    self.borderRadius = MYCRoundingDefaultRadius;
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

- (void) setBorderRadius:(CGFloat)borderRadius
{
    _borderRadius = borderRadius;
    self.layer.cornerRadius = _borderRadius;
}

- (void) setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    self.layer.borderColor = _borderColor.CGColor;
}

- (void) setBorderWidth:(CGFloat)borderWidth
{
    _borderWidth = borderWidth;
    self.layer.borderWidth = _borderWidth;
}

- (void) setMYCRoundedCorners
{
    self.borderRadius = MYCRoundingDefaultRadius;
    self.layer.masksToBounds = YES;
}

// placeholder position
- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 2*self.borderRadius, self.borderRadius);
}

// text position
- (CGRect)editingRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 2*self.borderRadius, self.borderRadius);
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

- (void) setBorderRadius:(CGFloat)borderRadius
{
    _borderRadius = borderRadius;
    self.layer.cornerRadius = _borderRadius;
}

- (void) setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    self.layer.borderColor = _borderColor.CGColor;
}

- (void) setBorderWidth:(CGFloat)borderWidth
{
    _borderWidth = borderWidth;
    self.layer.borderWidth = _borderWidth;
}

- (void) setMYCRoundedCorners
{
    self.borderRadius = MYCRoundingDefaultRadius;
    self.layer.masksToBounds = YES;
}

@end

