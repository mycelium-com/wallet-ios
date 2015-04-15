//
//  MYCVerifyBackupViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 13.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCVerifyBackupViewController.h"
#import "MYCWallet.h"
#import "MYCUnlockedWallet.h"
#import <CoreBitcoin/CoreBitcoin.h>

@interface MYCVerifyBackupViewController ()
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@end

@implementation MYCVerifyBackupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    // Do any additional setup after loading the view.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.textView.text = @"";
    self.title = NSLocalizedString(@"Verify Backup", @"");

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
}

- (NSArray*) currentWords
{
    NSArray* words = [[[[[[[[[self.textView.text lowercaseStringWithLocale:[NSLocale currentLocale]]
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

- (IBAction)verify:(id)sender {

    NSArray* words = [self currentWords];
    if (words.count < 12) {
        [self invalidSeed];
        return;
    }

    BTCMnemonic* mnemonic = [[BTCMnemonic alloc] initWithWords:words
                                                      password:@""
                                                  wordListType:BTCMnemonicWordListTypeEnglish];

    if (!mnemonic || !mnemonic.keychain || !mnemonic.seed) {
        [self invalidSeed];
        return;
    }

    __block BOOL matches = NO;
    [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *uw) {

        BTCMnemonic* m2 = [uw readMnemonic];
        if ([m2.seed isEqual:mnemonic.seed]) {
            matches = YES;
        } else {
            matches = NO;
        }

    } reason:NSLocalizedString(@"Verifying that backup matches this wallet.", @"")];

    if (matches) {
        if (self.completionBlock) self.completionBlock(YES);
        self.completionBlock = nil;
    } else {
        [self nonMatchingSeed];
    }
}

- (void) invalidSeed {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup is invalid", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"Please check that you entered all words correctly.", @"")]
                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
}

- (void) nonMatchingSeed {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup does not match", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"This seed does not match this wallet.", @"")]
                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
}

- (void) cancel:(id)_ {
    if (self.completionBlock) self.completionBlock(NO);
    self.completionBlock = nil;
}

@end
