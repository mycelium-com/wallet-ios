//
//  MYCBackupViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBackupViewController.h"

@interface MYCBackupPageView : UIView
@property(nonatomic, weak) IBOutlet UILabel* label;
@property(nonatomic, weak) IBOutlet UIButton* button;
@end
@implementation MYCBackupPageView
@end

@interface MYCBackupViewController () <UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet MYCBackupPageView *existingPageView;

@property(nonatomic) UINib* nib;

@end

@implementation MYCBackupViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Backup your wallet", @"");
        self.nib = [UINib nibWithNibName:@"MYCBackupViewController" bundle:nil];
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
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.scrollView.subviews.count <= 1)
    {
        NSArray* words = @[@"quick", @"brown", @"fox", @"jumped", @"over", @"the", @"lazy", @"dog", @"and", @"ate", @"its", @"breakfast"];

        for (NSString* word in words)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.scrollView addSubview:[self pageViewWithText:word button:NSLocalizedString(@"Next word", @"") action:@selector(nextPage:)]];
                [self.view setNeedsLayout];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scrollView addSubview:[self pageViewWithText:NSLocalizedString(@"Please enter all words to verify they are written correctly", @"") button:NSLocalizedString(@"Next", @"") action:@selector(nextPage:)]];
        });

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scrollView addSubview:[self pageViewWithText:NSLocalizedString(@"The backup is complete. Keep your master seed safe. You can use it to restore your wallet when you install Mycelium Wallet on another device (or reinstall on this one).", @"") button:NSLocalizedString(@"Finish", @"") action:@selector(finish:)]];

            self.pageControl.numberOfPages = self.scrollView.subviews.count;
            [self scrollViewDidScroll:self.scrollView];
        });
    }
}

- (void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    NSLog(@"!!! layout: %@", @(self.scrollView.subviews.count));

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
    MYCBackupPageView* pageView = self.existingPageView ?: [self.nib instantiateWithOwner:[NSMutableDictionary dictionary] options:nil][1];

    self.existingPageView = nil; // do not use further.

    pageView.label.text = text;
    [pageView.button setTitle:buttonLabel ?: @"" forState:UIControlStateNormal];

    if (buttonLabel && selector)
    {
        [pageView.button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    }

    return pageView;
}

- (void) nextPage:(id)_
{
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


#pragma mark - UIScrollViewDelegate



- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    self.pageControl.currentPage = (NSInteger)round(scrollView.contentOffset.x / scrollView.bounds.size.width);
}


@end
