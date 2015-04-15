//
//  MYCWelcomeViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWelcomeViewController.h"
#import "MYCBackupViewController.h"
#import "MYCAppDelegate.h"

#import "MYCWallet.h"
#import "MYCUnlockedWallet.h"

#import <CoreMotion/CoreMotion.h>
#import <CoreBitcoin/CoreBitcoin.h>
#import <CommonCrypto/CommonCrypto.h>

@interface MYCWelcomeViewController ()<UITextViewDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

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

@property (strong, nonatomic) IBOutlet UIView *restorePassphraseWalletView;
@property (weak, nonatomic) IBOutlet UILabel *restorePassphraseLabel;
@property (weak, nonatomic) IBOutlet UITextView *restorePassphraseTextView;
@property (weak, nonatomic) IBOutlet UIButton* restorePassphraseCancelButton;
@property (weak, nonatomic) IBOutlet UIButton* restorePassphraseCompleteButton;

@property (strong, nonatomic) IBOutlet UIView *backupWarningView;

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

    NSString* _restorePlaceholderText;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        _restorePlaceholderText = @"chancellor brink second bailout banks...";

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.generatingLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Shake your %@ to generate a unique master key to your wallet.", @""), [UIDevice currentDevice].localizedModel];
}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

- (BOOL) automaticallyAdjustsScrollViewInsets
{
    return YES;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [(UIScrollView*)self.view setContentInset:UIEdgeInsetsZero];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![MYCUnlockedWallet isPasscodeSet]) {


            UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Passcode is not set", @"Errors")
                                                                           message:NSLocalizedString(@"To protect your bitcoins please set up a passcode or Touch ID in System Settings.", @"")
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [MYCUnlockedWallet setBypassMissingPasscode];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void) setupWalletWithMnemonic:(BTCMnemonic*)mnemonic newWallet:(BOOL)newWallet
{
    MYCWallet* wallet = [MYCWallet currentWallet];

    [wallet unlockWallet:^(MYCUnlockedWallet *unlockedWallet) {

        // This will write the mnemonic to iOS keychain.
        unlockedWallet.mnemonic = mnemonic;

        if (unlockedWallet.error) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                        message:unlockedWallet.error.localizedDescription ?: @""
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                              otherButtonTitles:nil] show];
            return;
        }

//        // This will write the mnemonic to iOS data-protected file.
//        if (![unlockedWallet makeFileBasedMnemonic:mnemonic]) {
//            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
//                                        message:unlockedWallet.error.localizedDescription ?: @""
//                                       delegate:nil
//                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
//                              otherButtonTitles:nil] show];
//            return;
//        }

        [wallet setupDatabaseWithMnemonic:mnemonic];

        //unlockedWallet.probeItem = YES;
        //wallet.migratedToTouchID = YES;

        void(^updateWallet)() = ^{
            [wallet updateActiveAccounts:^(BOOL success, NSError *error) {}];
            [wallet updateExchangeRate:YES completion:^(BOOL success, NSError *error) {}];
        };

        if (newWallet) {
            updateWallet();
        } else {
            [wallet discoverAccounts:unlockedWallet.keychain completion:^(BOOL success, NSError *error) {
                if (!success) {
                    MYCError(@"MYCWelcomeViewController: failed to discover accounts. Please add them manually. %@", error);
                } else {
                    updateWallet();
                }
            }];
        }

    } reason:NSLocalizedString(@"Authenticate storage for the wallet seed", @"")];


}

- (IBAction)createNewWallet:(id)sender
{
    // Mark that we begin the setup so user has to go through all warnings before being able to deposit funds.
    [MYCWallet currentWallet].walletSetupInProgress = YES;

    self.generatingWalletView.frame = self.containerView.bounds;
    self.generatingWalletView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.generatingWalletView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.generatingWalletView];

    self.generatingProgressView.progress = 0.0;

    [self generateRandomMnemonic:^(BTCMnemonic *mnemonic) {

        [self.generatingProgressView setProgress:1.0 animated:YES];

        // Prepare a database and store the mnemonic in the keychain

        [self setupWalletWithMnemonic:mnemonic newWallet:YES];
        [self displayWarningAboutBackup];

    } progress:^(double pr) {
        self.generatingProgressView.progress = pr;
    }];

}

- (void) displayWarningAboutBackup {
    self.backupWarningView.frame = self.containerView.bounds;
    self.backupWarningView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.backupWarningView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.backupWarningView];

    // Let user choose to backup or not.
}

- (IBAction)backupLater:(id)sender {
    UIAlertController* alert2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Do you understand the risk?", @"")
                                                                    message:NSLocalizedString(@"Without a backup, there is no guarantee that you will be able to access your funds after depositing them into the wallet. There is no warranty. Any software or hardware may fail any time. Your wallet is not linked to your email or phone number. Mycelium does not keep copies of your private keys. The only way to protect your funds is to make your own backup and store it in a safe place.\n\nIf you proceed without backup, you take full reposibility for any potential losses.", @"")
                                                             preferredStyle:UIAlertControllerStyleAlert];
//    [alert2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"I understand, proceed without backup", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
//        [self beginUsingNewWallet];
//    }]];
    [alert2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Back up now", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self backupNow:nil];
    }]];
    [self presentViewController:alert2 animated:YES completion:nil];
}

- (IBAction) backupNow:(id)sender {

    MYCBackupViewController* vc = [[MYCBackupViewController alloc] initWithNibName:nil bundle:nil];
    vc.completionBlock = ^(BOOL finished){
        [self dismissViewControllerAnimated:YES completion:nil];

        if ([MYCWallet currentWallet].isBackedUp) {
            [self beginUsingNewWallet];
        }
    };
    UINavigationController* navc = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:navc animated:YES completion:nil];

}

- (void) beginUsingNewWallet {
    [MYCWallet currentWallet].walletSetupInProgress = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[MYCAppDelegate sharedInstance] displayMainView];
    });
}




- (IBAction)restoreFromBackup:(id)sender
{
    self.restoreWalletView.frame = self.containerView.bounds;
    self.restoreWalletView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.restoreWalletView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.restoreWalletView];

    self.restoreLabel.text = NSLocalizedString(@"Type in your 12-word master seed (separated by spaces)", @"");
    [self.restoreCancelButton setTitle:NSLocalizedString(@"Back", @"") forState:UIControlStateNormal];
    [self.restoreCompleteButton setTitle:NSLocalizedString(@"Next", @"") forState:UIControlStateNormal];

    self.restoreTextView.text = @"";

    [self updateRestoreUI];
    [self updateRestorePlaceholder];
}

- (IBAction)cancelRestore:(id)sender
{
    [self.restoreWalletView removeFromSuperview];
}

- (IBAction)cancelRestorePassphrase:(id)sender
{
    [self.restorePassphraseWalletView removeFromSuperview];
}

- (IBAction)goToPassphrase:(id)sender
{
    self.restorePassphraseWalletView.frame = self.containerView.bounds;
    self.restorePassphraseWalletView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.restorePassphraseWalletView.translatesAutoresizingMaskIntoConstraints = YES;
    [self.containerView addSubview:self.restorePassphraseWalletView];

    self.restorePassphraseLabel.text = NSLocalizedString(@"Enter a passphrase\n(omit passphrase if you did not specify it while creating a wallet)", @"");
    [self.restorePassphraseCancelButton setTitle:NSLocalizedString(@"Back", @"") forState:UIControlStateNormal];
    [self.restorePassphraseCompleteButton setTitle:NSLocalizedString(@"Continue", @"") forState:UIControlStateNormal];

    self.restorePassphraseTextView.text = @"";

    [self updateRestoreUI];
    [self updateRestorePlaceholder];
}

- (IBAction)finishRestore:(id)sender
{
    [self.view endEditing:YES];

    BTCMnemonic* mnemonic = [[BTCMnemonic alloc] initWithWords:[self currentWords]
                                                      password:self.restorePassphraseTextView.text
                                                  wordListType:BTCMnemonicWordListTypeEnglish];

    if (mnemonic && mnemonic.keychain)
    {
        [MYCWallet currentWallet].walletSetupInProgress = NO;
        [self setupWalletWithMnemonic:mnemonic newWallet:NO];
        
        // Remember that the wallet is backed up now.
        [MYCWallet currentWallet].backedUp = YES;

        [[MYCAppDelegate sharedInstance] displayMainView];
    }
    else
    {
        self.restoreLabel.text = NSLocalizedString(@"Failed to restore wallet with this mnemonic", @"");
        self.restoreLabel.textColor = [UIColor redColor];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView.text.length > 0)
    {
        [self updateRestoreUI];
    }
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self updateRestorePlaceholder];
    [self updateRestoreUI];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self updateRestorePlaceholder];
    [self updateRestoreUI];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqualToString:@"\n"])
    {
        // User tapped "Done" button, simply add another space.
        [textView resignFirstResponder];
        [self updateRestoreUI];
        return NO;
    }
    return YES;
}

- (void) updateRestorePlaceholder
{
    if (!_restorePlaceholderText) return;

    NSString* text = [[self currentWords] componentsJoinedByString:@" "];

    if (self.restoreTextView.isFirstResponder)
    {
        if ([self.restoreTextView.text isEqualToString:_restorePlaceholderText])
        {
            self.restoreTextView.text = @"";
        }
        self.restoreTextView.textColor = [UIColor blackColor];
    }
    else
    {
        if (text.length == 0 || [self.restoreTextView.text isEqualToString:_restorePlaceholderText])
        {
            self.restoreTextView.text = _restorePlaceholderText;
            self.restoreTextView.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
        }
        else
        {
            self.restoreTextView.textColor = [UIColor blackColor];
        }
    }
}

- (void) updateRestoreUI
{
    self.restoreLabel.text = NSLocalizedString(@"Type in your 12-word master seed separated by spaces", @"");
    self.restoreLabel.textColor = [UIColor blackColor];

    self.restoreCompleteButton.enabled = NO;

    NSArray* words = [self currentWords];

    if (words.count > 12)
    {   
        self.restoreLabel.text = NSLocalizedString(@"Too many words entered.", @"");
        self.restoreLabel.textColor = [UIColor redColor];
    }
    else if (words.count == 12)
    {
        BTCMnemonic* mnemonic = [[BTCMnemonic alloc] initWithWords:words password:nil wordListType:BTCMnemonicWordListTypeEnglish];

        // If words are valid, checksum is good, we'll have some entropy here
        if (mnemonic.entropy)
        {
            self.restoreLabel.text = NSLocalizedString(@"Master seed is correct.", @"");
            self.restoreLabel.textColor = [UIColor colorWithHue:0.33 saturation:1.0 brightness:0.6 alpha:1.0];
            self.restoreCompleteButton.enabled = YES;
        }
        else
        {
            self.restoreLabel.text = NSLocalizedString(@"Master seed is incorrect.", @"");
            self.restoreLabel.textColor = [UIColor redColor];
        }
    }
    else if (!self.restoreTextView.isFirstResponder &&
             words.count > 0 &&
             !(_restorePlaceholderText && [self.restoreTextView.text isEqual:_restorePlaceholderText]))
    {
        self.restoreLabel.text = NSLocalizedString(@"Master seed is incorrect.", @"");
        self.restoreLabel.textColor = [UIColor redColor];
    }
}

- (NSArray*) currentWords
{
    NSArray* words = [[[[[[[[[self.restoreTextView.text lowercaseStringWithLocale:[NSLocale currentLocale]]
                                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                                   stringByReplacingOccurrencesOfString:@"\n" withString:@" "]
                                  stringByReplacingOccurrencesOfString:@"," withString:@" "]
                                 stringByReplacingOccurrencesOfString:@"." withString:@" "]
                                stringByReplacingOccurrencesOfString:@"  " withString:@" "]
                               stringByReplacingOccurrencesOfString:@"  " withString:@" "]
                              stringByReplacingOccurrencesOfString:@"  " withString:@" "]
                             componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (words.count == 1 && [words.firstObject isEqualToString:@""])
    {
        return @[];
    }

    return words;
}



- (void)keyboardWillShow:(NSNotification*)notif
{
    [self updateWithKeyboardNotification:notif block:^(CGRect keyboardRect) {
        self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, keyboardRect.size.height, 0);

        [self.scrollView scrollRectToVisible:[self.scrollView convertRect:CGRectInset(self.restoreCompleteButton.frame, 0, -20)
                                                                 fromView:self.restoreTextView.superview] animated:NO];
    }];
}

- (void)keyboardWillHide:(NSNotification*)notif
{
    [self updateWithKeyboardNotification:notif block:^(CGRect keyboardRect) {
        self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, keyboardRect.size.height, 0);
    }];
}

- (void) updateWithKeyboardNotification:(NSNotification*)notif block:(void(^)(CGRect keyboardRect))block
{
    NSDictionary* info = [notif userInfo];

    CGRect localKeyboardRect = CGRectMake(0, 0, 0, 0);

    if ([notif.name isEqualToString:UIKeyboardWillShowNotification])
    {
        CGRect keyboardRect = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        localKeyboardRect = [self.view convertRect:keyboardRect fromView:self.view.window];
        localKeyboardRect = CGRectIntersection(localKeyboardRect, self.view.bounds); // shorten keyboard height appropriately.
        if (localKeyboardRect.size.height < 0.1) localKeyboardRect = CGRectZero;
    }

    NSTimeInterval animationDuration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve animationCurve = [info[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    if (animationDuration < 0.01) animationDuration = 0.0;

    if (animationDuration > 0.0)
    {
        [UIView beginAnimations:@"keyboardAppearance" context:NULL];
        [UIView setAnimationCurve:animationCurve];
        [UIView setAnimationDuration:animationDuration];
    }

    block(localKeyboardRect);

    if (animationDuration > 0.0)
    {
        [UIView commitAnimations];
    }
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

    // First, get the random bytes from /dev/urandom.
    // We'll mix in bytes from accelerometer.
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

            double entropy = pow(10*(entropyX + entropyY + entropyZ)*0.66/256.0, 1.41); // make entropy counted more quickly towards the end.

            CC_SHA256_Update(&_shaCTX, &acc, sizeof(acc));

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

                    // Our seed is random 128 bits to form 12 mnemonic words.
                    completionBlock([[BTCMnemonic alloc] initWithEntropy:BTCDataRange(seed, NSMakeRange(0, 16)) password:nil wordListType:BTCMnemonicWordListTypeEnglish]);
                });
            }
        }];

    }
    else // simulator does not have motion sensor
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

            double progress = 0;
            double speed = 0.02;
            while (progress < 1.0 && _queue)
            {
                usleep(10000);
                progress += speed;
                speed += speed*0.2*(2*drand48() - 1.0);

                dispatch_async(dispatch_get_main_queue(), ^{
                    progressBlock(progress);
                });
            }

            dispatch_async(dispatch_get_main_queue(), ^{

                // On simulator we can afford a simple random seed.
                completionBlock([[BTCMnemonic alloc] initWithEntropy:BTCRandomDataWithLength(16) password:nil wordListType:BTCMnemonicWordListTypeEnglish]);
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


