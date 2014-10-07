//
//  MYCWelcomeViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWelcomeViewController.h"
#import "MYCAppDelegate.h"

#import "MYCWallet.h"

#import <CoreMotion/CoreMotion.h>
#import <CoreBitcoin/CoreBitcoin.h>
#import <CommonCrypto/CommonCrypto.h>

@interface MYCWelcomeViewController ()<UITextViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UILabel *welcomeMessageLabel;
@property (weak, nonatomic) IBOutlet UIButton *createWalletButton;
@property (weak, nonatomic) IBOutlet UIButton *restoreButton;

@property (strong, nonatomic) IBOutlet UIView *generatingWalletView;
@property (weak, nonatomic) IBOutlet UILabel *generatingLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *generatingProgressView;

@property (strong, nonatomic) IBOutlet UIView *restoreWalletView;
@property (weak, nonatomic) IBOutlet UILabel *restoreLabel;
@property (weak, nonatomic) IBOutlet UITextView *restoreTextView;
@property (weak, nonatomic) IBOutlet UIButton* restoreCancelButton;
@property (weak, nonatomic) IBOutlet UIButton* restoreCompleteButton;

@end

@interface MYCEntropyMeter : NSObject
- (double) consumePoint:(double)point;
@end


@implementation MYCWelcomeViewController {
    CMMotionManager* _motionManager;
    NSOperationQueue* _queue;
    MYCEntropyMeter* _entropyMeterX;
    MYCEntropyMeter* _entropyMeterY;
    MYCEntropyMeter* _entropyMeterZ;
    CC_SHA256_CTX _shaCTX;

}

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

- (IBAction)createNewWallet:(id)sender
{
    self.generatingWalletView.frame = self.containerView.bounds;
    self.generatingWalletView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.generatingWalletView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.generatingWalletView];

    self.generatingProgressView.progress = 0.0;

    [self generateRandomMnemonic:^(BTCMnemonic *mnemonic) {

        [self.generatingProgressView setProgress:1.0 animated:YES];

        // TODO: prepare a database and store the mnemonic in the keychain
        NSLog(@"Mnemonic: %@", mnemonic.dataWithSeed);

        MYCWallet* wallet = [MYCWallet currentWallet];

        [wallet unlockWallet:^(MYCUnlockedWallet *unlockedWallet) {

            // This will write the mnemonic to iOS keychain.
            unlockedWallet.mnemonic = mnemonic;

        } reason:NSLocalizedString(@"Authenticate to store master key on the device", @"")];

        [wallet setupDatabaseWithMnemonic:mnemonic];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[MYCAppDelegate sharedInstance] displayMainView];
        });

    } progress:^(double pr) {
        self.generatingProgressView.progress = pr;
    }];

}

- (IBAction)restoreFromBackup:(id)sender
{
    self.restoreWalletView.frame = self.containerView.bounds;
    self.restoreWalletView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.restoreWalletView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.restoreWalletView];

    [self.restoreCancelButton setTitle:NSLocalizedString(@"Cancel", @"") forState:UIControlStateNormal];
    [self.restoreCompleteButton setTitle:NSLocalizedString(@"Continue", @"") forState:UIControlStateNormal];

    self.restoreTextView.text = @"";
    [self updateRestoreUI];
}

- (IBAction)cancelRestore:(id)sender
{
    [self.restoreWalletView removeFromSuperview];
}

- (IBAction)finishRestore:(id)sender
{
#warning TODO: setup the wallet and display the main view.

    [[MYCAppDelegate sharedInstance] displayMainView];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView.text.length > 0)
    {
        [self updateRestoreUI];
    }
}

- (void) updateRestoreUI
{
    self.restoreLabel.text = NSLocalizedString(@"Type in your 12-word master seed separated by spaces", @"");

    self.restoreCompleteButton.enabled = NO;

    NSArray* words = [self currentWords];

    if (words.count > 12)
    {   
        self.restoreLabel.text = NSLocalizedString(@"Too many words entered.", @"");
    }
    else if (words.count == 12)
    {
        BTCMnemonic* mnemonic = [[BTCMnemonic alloc] initWithWords:words password:nil wordListType:BTCMnemonicWordListTypeEnglish];

        // If words are valid, checksum is good, we'll have some entropy here
        if (mnemonic.entropy)
        {
            self.restoreLabel.text = NSLocalizedString(@"Master seed is correct.", @"");
            self.restoreCompleteButton.enabled = YES;
        }
        else
        {
            self.restoreLabel.text = NSLocalizedString(@"Master seed is incorrect.", @"");
        }
    }
}

- (NSArray*) currentWords
{
    return [[[self.restoreTextView.text lowercaseStringWithLocale:[NSLocale currentLocale]]
             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}



#pragma mark - Private Methods


- (void) generateRandomMnemonic:(void(^)(BTCMnemonic*))completionBlock progress:(void(^)(double))progressBlock
{
    _queue = [[NSOperationQueue alloc] init];
    _queue.maxConcurrentOperationCount = 1;

    _entropyMeterX = [[MYCEntropyMeter alloc] init];
    _entropyMeterY = [[MYCEntropyMeter alloc] init];
    _entropyMeterZ = [[MYCEntropyMeter alloc] init];

    CC_SHA256_Init(&_shaCTX);

    NSData* systemRandom = BTCRandomDataWithLength(32);

    CC_SHA256_Update(&_shaCTX, systemRandom.bytes, (CC_LONG)systemRandom.length);

    #if TARGET_IPHONE_SIMULATOR
    const BOOL simulator = YES;
    #else
    const BOOL simulator = NO;
    #endif

    if (!simulator)
    {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 1/30.0;
        [_motionManager startAccelerometerUpdatesToQueue:_queue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {

            CMAcceleration acc = accelerometerData.acceleration;

            double entropyX = [_entropyMeterX consumePoint:acc.x];
            double entropyY = [_entropyMeterY consumePoint:acc.y];
            double entropyZ = [_entropyMeterZ consumePoint:acc.z];

            double entropy = pow(10*(entropyX + entropyY + entropyZ)*0.5/256.0, 1.41); // make entropy counted more quickly towards the end.

            CC_SHA256_Update(&_shaCTX, &acc, sizeof(acc));

            //NSLog(@"data: %@ (%f)", accelerometerData, entropy);

            if (entropy <= 1.005)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(entropy);
                });
            }
            else
            {
                unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                CC_SHA256_Final(digest, &_shaCTX);

                NSMutableData* seed = [NSMutableData dataWithBytes:&digest length:CC_SHA256_DIGEST_LENGTH];

                BTCSecureMemset(digest, 0, CC_SHA256_DIGEST_LENGTH);
                BTCSecureMemset(&_shaCTX, 0, sizeof(_shaCTX));

                dispatch_async(dispatch_get_main_queue(), ^{

                    if (!_motionManager) return;

                    [_motionManager stopAccelerometerUpdates];
                    _motionManager = nil;
                    _queue = nil;

                    completionBlock([[BTCMnemonic alloc] initWithEntropy:seed password:nil wordListType:BTCMnemonicWordListTypeEnglish]);
                });
            }
        }];

    }
    else // simulator does not have motion sensor
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

            double progress = 0;
            double speed = 0.0066;
            while (progress < 1.0 && _queue)
            {
                usleep(10000);
                progress += speed;
                speed += 0.000001*(2*drand48() - 1.0);

                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(progress);
                });
            }

            dispatch_async(dispatch_get_main_queue(), ^{

                // On simulator we can afford a simple random seed.
                completionBlock([[BTCMnemonic alloc] initWithEntropy:BTCRandomDataWithLength(32) password:nil wordListType:BTCMnemonicWordListTypeEnglish]);
            });
        });
    }
}


@end






@implementation MYCEntropyMeter {
    double _prev0;
    double _prev1;
    double _prev2;
    double _entropy;
    int _steps;
}

- (double) consumePoint:(double)point
{
    double delta1 = ABS(ABS(point) - ABS(_prev0)); // speed
    double delta2 = ABS(delta1 - _prev1); // acceleration
    double delta3 = ABS(delta2 - _prev2);

    _prev0 = point;
    _prev1 = delta1;
    _prev2 = delta2;

    _steps++;

    double delta = delta3;

    // First ten inputs are compensated to avoid sharp jumps
    if (_steps < 10)
    {
        delta = delta3 * (0.1*_steps);
    }

    _entropy += log(1.0 + delta);

    return _entropy;
}
@end


