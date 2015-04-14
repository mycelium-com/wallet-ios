//
//  MYCBackupViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBackupPageView.h"
#import "MYCBackupViewController.h"
#import "MYCWallet.h"
#import "MYCErrorAnimation.h"

@interface MYCBackupViewController () <UIScrollViewDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet UITextField* verifyTextField;

@property(nonatomic) UINib* pageNib;

@property(nonatomic) NSArray* words;

@end

@implementation MYCBackupViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Backup your wallet", @"");
        self.pageNib = [UINib nibWithNibName:@"MYCBackupPageView" bundle:nil];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancel:)];
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.scrollView addSubview:[self pageViewWithText:NSLocalizedString(@"You are about to back up a master seed of your wallet. This seed allows anyone knowing it to spend all funds from your wallet.\n\nYou will see a list of words, one by one. Write them down and store in a safe place.", @"") button:NSLocalizedString(@"Start", @"") action:@selector(start:)]];

    [self scrollViewDidScroll:self.scrollView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.pageControl.hidden = YES;
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self.view endEditing:YES];
}

- (void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width*self.scrollView.subviews.count,
                                             self.view.bounds.size.height - self.topLayoutGuide.length - self.bottomLayoutGuide.length);

    CGFloat offset = 0;

    for (UIView* v in self.scrollView.subviews)
    {
        v.frame = CGRectMake(offset, 0, self.scrollView.bounds.size.width, self.scrollView.contentSize.height);
        offset += v.frame.size.width;
    }
}

- (MYCBackupPageView*) pageViewWithText:(NSString*)text button:(NSString*)buttonLabel action:(SEL)selector
{
    MYCBackupPageView* pageView = [self.pageNib instantiateWithOwner:self options:nil][0];

    pageView.label.textAlignment = text.length > 20 ? NSTextAlignmentLeft : NSTextAlignmentCenter;

    pageView.label.text = text;
    [pageView.button setTitle:buttonLabel ?: @"" forState:UIControlStateNormal];

    pageView.textField.hidden = YES;

    if (buttonLabel && selector)
    {
        [pageView.button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    }

    return pageView;
}

- (void) start:(id)_
{
    if (!self.words)
    {
        [[MYCWallet currentWallet] bestEffortAuthenticateWithTouchID:^(MYCUnlockedWallet *uw, BOOL authenticated) {

            if (!uw) { // user not authorized, do nothing.
                return;
            }

            BTCMnemonic* mnemonic = [uw readMnemonic];

            if (!mnemonic) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                            message:[NSString stringWithFormat:@"You may need to restore wallet from backup. %@", uw.error.localizedDescription ?: @""] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] show];
                return;
            }

            self.words = mnemonic.words;

            for (NSString* word in self.words)
            {
                [self.scrollView addSubview:[self pageViewWithText:word button:NSLocalizedString(@"Next word", @"") action:@selector(nextPage:)]];
            }

            MYCBackupPageView* validatePage = [self pageViewWithText:NSLocalizedString(@"Please enter all words separated by space to verify they are written correctly", @"") button:NSLocalizedString(@"Next", @"") action:@selector(verifyWords:)];
            validatePage.textField.hidden = NO;
            self.verifyTextField = validatePage.textField;
            [self.verifyTextField addTarget:self action:@selector(didUpdateVerifyTextField:) forControlEvents:UIControlEventEditingChanged];
            [self.scrollView addSubview:validatePage];

            self.pageControl.numberOfPages = self.scrollView.subviews.count;
            [self scrollViewDidScroll:self.scrollView];

        } reason:NSLocalizedString(@"Authorize access to the backup", @"")];

    }
    [self nextPage:_];
}

- (void) nextPage:(id)_
{
    // Do not show page control to avoid distraction
    // self.pageControl.hidden = NO;
    CGPoint offset = self.scrollView.contentOffset;
    offset.x += self.scrollView.bounds.size.width;
    [self.scrollView setContentOffset:offset animated:YES];
}

- (void) verifyWords:(id)_
{
    NSArray* enteredWords = [[[[[[[[[self.verifyTextField.text lowercaseStringWithLocale:[NSLocale currentLocale]]
                                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                                   stringByReplacingOccurrencesOfString:@"\n" withString:@" "]
                                  stringByReplacingOccurrencesOfString:@"," withString:@" "]
                                 stringByReplacingOccurrencesOfString:@"." withString:@" "]
                                stringByReplacingOccurrencesOfString:@"  " withString:@" "]
                               stringByReplacingOccurrencesOfString:@"  " withString:@" "]
                              stringByReplacingOccurrencesOfString:@"  " withString:@" "]
                             componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([enteredWords isEqual:self.words])
    {
        // Remember that the wallet is backed up now.
        [MYCWallet currentWallet].backedUp = YES;

        [self.scrollView addSubview:[self pageViewWithText:NSLocalizedString(@"The backup is complete. Keep your master seed safe. You can use it to restore your wallet when you install Mycelium Wallet on another device (or reinstall on this one).", @"") button:NSLocalizedString(@"Finish", @"") action:@selector(finish:)]];

        self.pageControl.numberOfPages = self.scrollView.subviews.count;
        [self scrollViewDidScroll:self.scrollView];

        [self nextPage:_];
    }
    else
    {
        [MYCErrorAnimation animateError:self.verifyTextField radius:16.0];
    }
}

- (void) finish:(id)_
{
    [self complete:YES];
}

- (void) cancel:(id)_
{
    [self complete:NO];
}

- (void) complete:(BOOL)finished
{
    if (self.completionBlock) self.completionBlock(finished);
    self.completionBlock = nil;
}



#pragma mark - UITextFieldDelegate


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    return YES;
}

- (void) didUpdateVerifyTextField:(UITextField*)textField
{
    NSMutableAttributedString* as = [[NSMutableAttributedString alloc] initWithString:textField.text];

    NSInteger offset = 0;
    for (NSString* word in self.words)
    {
        NSRange r = [as.string rangeOfString:word options:NSCaseInsensitiveSearch range:NSMakeRange(offset, as.string.length - offset)];
        if (r.length == 0) break;

        [as setAttributes:@{
                            NSForegroundColorAttributeName: [UIColor colorWithHue:0.33 saturation:1.0 brightness:0.5 alpha:1.0]
                            } range:r];
    }

    textField.attributedText = as;
}


#pragma mark - UIScrollViewDelegate



- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSInteger p = (NSInteger)round(scrollView.contentOffset.x / scrollView.bounds.size.width);

    if (p != self.pageControl.currentPage)
    {
        [self.view endEditing:YES];
    }

    self.pageControl.currentPage = p;


    for (UIView* v in scrollView.subviews)
    {
        if ([v isKindOfClass:[MYCBackupPageView class]])
        {
            MYCBackupPageView* pv = (id)v;

            CGPoint p = [self.view convertPoint:pv.button.center fromView:pv];
            CGFloat diff = ABS(p.x - self.view.bounds.size.width/2.0);
            pv.button.alpha = 1.0 - diff/50.0;
        }
    }

}


@end
