//
//  MYCScannerView.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCScannerView.h"
#import <AVFoundation/AVFoundation.h>

@interface MYCScannerView ()
@property(nonatomic, weak) UIView* shadowView;
@property(nonatomic, strong) UIView* videoView;
@property(nonatomic, strong) UILabel* messageLabel;
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
    CGRect finalRect = CGRectMake(finalCenter.x - side/2.0, finalCenter.y - side/2.0 - 0.1*view.bounds.size.height, side, side);

    [UIView animateWithDuration:0.1 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        shadowView.alpha = 1.0;
    } completion:^(BOOL finished) {}];

    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        scannerView.frame = finalRect;
    } completion:^(BOOL finished) {}];

    UITapGestureRecognizer* tapGR = [[UITapGestureRecognizer alloc] initWithTarget:scannerView action:@selector(dismiss)];
    shadowView.userInteractionEnabled = YES;
    [shadowView addGestureRecognizer:tapGR];

//    if ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusDenied)
//    {
//        scannerView.errorMessage = NSLocalizedString(@"Please allow camera access in system settings.", @"");
//    }

    return scannerView;
}

+ (void) checkPermissionToUseCamera:(void(^)(BOOL granted))completion
{
    if ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusAuthorized)
    {
        completion(YES);
    }
    else
    {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted)
            {
                completion(YES);
            }
            else
            {
                completion(NO);
                return;
            }
        }];
    }
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

        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 10)];
        self.messageLabel.numberOfLines = 0;
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        self.messageLabel.font = [UIFont systemFontOfSize:17];
        self.messageLabel.adjustsFontSizeToFitWidth = YES;
        self.messageLabel.minimumScaleFactor = 0.5;
        self.messageLabel.text = @""; //@"Very long text to test multiline message around QR code. Really long and wide text.";
        self.messageLabel.textColor = [UIColor whiteColor];
        [self addSubview:self.messageLabel];

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

    if (self.messageLabel.superview != self.superview)
    {
        [self.superview addSubview:self.messageLabel];
    }
    CGRect fr = CGRectZero;
    fr.size = [self.messageLabel sizeThatFits:CGSizeMake(self.superview.bounds.size.width - 40.0, 200)];
    self.messageLabel.frame = fr;
    self.messageLabel.center = CGPointMake(self.center.x, CGRectGetMaxY(self.frame) + 20 + self.messageLabel.frame.size.height);
}

- (void) setErrorMessage:(NSString *)errorMessage
{
    _errorMessage = errorMessage;
    self.messageLabel.text = errorMessage ?: @"";
    self.messageLabel.textColor = [UIColor colorWithHue:0.0 saturation:0.7 brightness:1.0 alpha:1.0];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self resetErrorLater];
}

- (void) setMessage:(NSString *)message
{
    _message = message;
    self.messageLabel.text = message ?: @"";
    self.messageLabel.textColor = [UIColor whiteColor];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self resetErrorLater];
}

- (void) resetErrorLater
{
    static int i = 0;
    i++;
    int j = i;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (j != i) return;
        self.message = nil;
    });
}

- (void) didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window)
    {
        self.videoView.frame = [self convertRect:self.superview.bounds fromView:self.superview];
        if (self.errorMessage) self.errorMessage = self.errorMessage;
        if (self.message) self.message = self.message;
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

    self.messageLabel.hidden = YES;

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
