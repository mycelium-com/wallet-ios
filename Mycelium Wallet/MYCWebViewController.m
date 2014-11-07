//
//  MYCWebViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 07.11.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCWebViewController.h"
//#import <WebKit/WebKit.h>

@interface MYCWebViewController ()<UIWebViewDelegate>
@property(nonatomic) UIWebView* webView;
@end

@implementation MYCWebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.webView.translatesAutoresizingMaskIntoConstraints = YES;
    self.webView.delegate = self;
    [self.view addSubview:self.webView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.URL)
    {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked && ![[request.URL absoluteString] containsString:self.URL.absoluteString])
    {
        [[UIApplication sharedApplication] openURL:request.URL];
        return NO;
    }
    return YES;
}

@end
