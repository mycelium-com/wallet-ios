//
//  MYCRestoreSeedViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 13.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCRestoreSeedViewController.h"
#import "MYCWallet.h"
#import "MYCWalletAccount.h"

@interface MYCRestoreSeedViewController ()
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@end

@implementation MYCRestoreSeedViewController

+ (void) promptToRestoreWallet:(NSError *)error in:(UIViewController*)hostVC {
    UIAlertController* ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Wallet Locked Out", @"")
                                                                message:[NSString stringWithFormat:@"You may need to restore wallet from backup.\n\n%@",
                                                                         error.localizedDescription ?: @""]
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"")
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action) {
                                         }]];
    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Restore", @"")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {

                                             MYCRestoreSeedViewController* vb = [[MYCRestoreSeedViewController alloc] initWithNibName:nil bundle:nil];

                                             vb.completionBlock = ^(BOOL restored, UIAlertController* alert) {
                                                 [hostVC dismissViewControllerAnimated:YES completion:nil];
                                                 [hostVC presentViewController:alert animated:YES completion:nil];
                                             };

                                             UINavigationController* navC = [[UINavigationController alloc] initWithRootViewController:vb];
                                             [hostVC presentViewController:navC animated:YES completion:nil];
                                         }]];
    
    [hostVC presentViewController:ac animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    // Do any additional setup after loading the view.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.textView.text = @"";
    self.title = NSLocalizedString(@"Restore Wallet", @"");

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

- (IBAction)restore:(id)sender {

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

    [[MYCWallet currentWallet] inDatabase:^(FMDatabase *db) {
        MYCWalletAccount* acc = [[MYCWalletAccount loadAllFromDatabase:db] firstObject];

        if (!acc) {
            MYCError(@"MYCRestoreSeedViewController: cannot find any account to match xpubs.");
            [self databaseInconsistency];
            return;
        }

        BTCKeychain* bitcoinKeychain = [MYCWallet currentWallet].isTestnet ? mnemonic.keychain.bitcoinTestnetKeychain : mnemonic.keychain.bitcoinMainnetKeychain;
        BTCKeychain* accKeychain = [bitcoinKeychain keychainForAccount:(uint32_t)acc.accountIndex];

        MYCLog(@"MYCRestoreSeedViewController: Account %@ xpub: %@", @(acc.accountIndex), acc.keychain.extendedPublicKey);
        MYCLog(@"MYCRestoreSeedViewController: Mnemonic's corresponding xpub: %@", accKeychain.extendedPublicKey);

        if ([accKeychain.extendedPublicKey isEqual:acc.keychain.extendedPublicKey]) {

            [[MYCWallet currentWallet] unlockWallet:^(MYCUnlockedWallet *uw) {

                uw.mnemonic = mnemonic;

                NSError* error = uw.error;
                if (!uw.mnemonic || ![uw.mnemonic.data isEqual:mnemonic.data]) {

                    MYCError(@"MYCRestoreSeedViewController: failed to save mnemonic correctly: %@", error);
                    [self keychainError:error];
                    return;
                }

                if (self.completionBlock) self.completionBlock(YES, [self restoredAlert]);
                self.completionBlock = nil;

            } reason:NSLocalizedString(@"Restoring the wallet seed", @"")];

        } else {
            MYCError(@"MYCRestoreSeedViewController: seed does not match account xpub in wallet DB");
            [self nonMatchingSeed];
        }
    }];
}

- (UIAlertController*) notRestoredAlert {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Wallet is not restored", @"")
                                                                    message:NSLocalizedString(@"To restore later, go to Settings and choose Restore from backup.", @"")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];

    return alert;
}

- (UIAlertController*) restoredAlert {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Wallet is restored", @"")
                                                                   message:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];

    return alert;
}

- (void) keychainError:(NSError*)error {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot restore wallet", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"iOS Keychain failed with error: %@", @""), error.localizedDescription]
                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
}


- (void) databaseInconsistency {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No account found", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"Please re-install the app if you have the backup or contact Mycelium support.", @"")]
                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
}

- (void) invalidSeed {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup is invalid", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"Please check that you entered all words correctly.", @"")]
                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
}

- (void) nonMatchingSeed {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Backup does not match", @"")
                                message:[NSString stringWithFormat:NSLocalizedString(@"This seed does not match this wallet. To restore from a different seed, re-install the app.", @"")]
                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
}

- (void) cancel:(id)_ {
    if (self.completionBlock) self.completionBlock(NO, [self notRestoredAlert]);
    self.completionBlock = nil;
}


@end
