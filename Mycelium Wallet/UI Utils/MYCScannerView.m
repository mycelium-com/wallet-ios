//
//  MYCScannerView.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCScannerView.h"

@interface MYCScannerView ()
@property(nonatomic, weak) UIView* shadowView;
@property(nonatomic, weak) UIView* videoView;
@property(nonatomic) CGRect initialRect;
@end

@implementation MYCScannerView

// Animates the view from a given rect and displays over the entire view.
+ (MYCScannerView*) presentFromRect:(CGRect)rect inView:(UIView*)view detection:(void(^)(NSString* message))detectionBlock
{
    if (!view) return nil;
    [view endEditing:YES];

    UIView* shadowView = [[UIView alloc] initWithFrame:view.bounds];
    shadowView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    shadowView.alpha = 0.0;

    MYCScannerView* scannerView = [[MYCScannerView alloc] initWithFrame:rect];

    scannerView.shadowView = shadowView;
    scannerView.detectionBlock = detectionBlock;

    [view addSubview:shadowView];
    [view addSubview:scannerView];

    scannerView.layer.masksToBounds = YES;
    scannerView.layer.cornerRadius = 2.0;

    CGFloat margin = 10.0;
    CGFloat side = MIN(view.bounds.size.width - margin*2,
                      MIN(view.bounds.size.height - margin*2,
                          round(view.bounds.size.width * 0.8)));

    CGPoint finalCenter = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
    CGRect finalRect = CGRectMake(finalCenter.x - side/2.0, finalCenter.y - side/2.0, side, side);

    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{

        shadowView.alpha = 1.0;
        scannerView.frame = finalRect;

    } completion:^(BOOL finished) {}];

    UITapGestureRecognizer* tapGR = [[UITapGestureRecognizer alloc] initWithTarget:scannerView action:@selector(dismiss)];
    shadowView.userInteractionEnabled = YES;
    [shadowView addGestureRecognizer:tapGR];

    return scannerView;
}

- (id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.initialRect = frame;

        __weak __typeof(self) weakself = self;
        self.videoView = [BTCQRCode scannerViewWithBlock:^(NSString *message) {
            if (weakself.detectionBlock) weakself.detectionBlock(message);
        }];

        self.backgroundColor = [UIColor blackColor];
        self.videoView.backgroundColor = [UIColor blackColor];
        [self addSubview:self.videoView];
    }
    return self;
}

- (void) layoutSubviews
{
    [super layoutSubviews];

    self.videoView.frame = [self convertRect:self.superview.bounds fromView:self.superview];
}

- (void) didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window)
    {
        self.videoView.frame = [self convertRect:self.superview.bounds fromView:self.superview];
    }
    else
    {
        self.detectionBlock = nil;
        [self.shadowView removeFromSuperview];
    }
}

- (void) dismiss
{
    self.detectionBlock = nil;

    [UIView animateWithDuration:0.20 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{

        self.shadowView.alpha = 0.0;
        self.frame = self.initialRect;
        self.alpha = 0.0;

    } completion:^(BOOL finished) {
        [self.shadowView removeFromSuperview];
        [self removeFromSuperview];
    }];
}

@end
