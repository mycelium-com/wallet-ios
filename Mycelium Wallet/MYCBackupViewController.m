//
//  MYCBackupViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBackupPageView.h"
#import "MYCBackupViewController.h"

@interface MYCBackupViewController () <UIScrollViewDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;

@property(nonatomic) UINib* pageNib;

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

    [self.scrollView addSubview:[self pageViewWithText:NSLocalizedString(@"You are about to back up your master wallet seed. This seed is not encrypted and allows to restore entire wallet contents.\n\nYou will see a list of words, one by one. Write them down and store in a safe place.", @"") button:NSLocalizedString(@"Start", @"") action:@selector(nextPage:)]];

    NSArray* words = @[@"quick", @"brown", @"fox", @"jumped", @"over", @"the", @"lazy", @"dog"];

    for (NSString* word in words)
    {
        [self.scrollView addSubview:[self pageViewWithText:word button:NSLocalizedString(@"Next word", @"") action:@selector(nextPage:)]];
    }

    MYCBackupPageView* validatePage = [self pageViewWithText:NSLocalizedString(@"Please enter all words to verify they are written correctly", @"") button:NSLocalizedString(@"Next", @"") action:@selector(nextPage:)];
    validatePage.textField.hidden = NO;
    [self.scrollView addSubview:validatePage];

    [self.scrollView addSubview:[self pageViewWithText:NSLocalizedString(@"The backup is complete. Keep your master seed safe. You can use it to restore your wallet when you install Mycelium Wallet on another device (or reinstall on this one).", @"") button:NSLocalizedString(@"Finish", @"") action:@selector(finish:)]];

    self.pageControl.numberOfPages = self.scrollView.subviews.count;
    [self scrollViewDidScroll:self.scrollView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.pageControl.hidden = YES;
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

    pageView.label.text = text;
    [pageView.button setTitle:buttonLabel ?: @"" forState:UIControlStateNormal];

    pageView.textField.hidden = YES;

    if (buttonLabel && selector)
    {
        [pageView.button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    }

    return pageView;
}

- (void) nextPage:(id)_
{
    self.pageControl.hidden = NO;
    CGPoint offset = self.scrollView.contentOffset;
    offset.x += self.scrollView.bounds.size.width;
    [self.scrollView setContentOffset:offset animated:YES];
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
