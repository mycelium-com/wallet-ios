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

    if (self.allowShare) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
    }

    if (self.html) {
        [self.webView loadHTMLString:self.html baseURL:self.URL];
    }
    else if (self.text) {
        // maybe need to wrap in <html><body>...
        [self.webView loadHTMLString:[NSString stringWithFormat:@""
                                      "<html><body><pre style='font-family:Menlo;font-size:12px;'>" // white-space: pre-wrap;
                                      "%@"
                                      "</pre></body></html>"
                                      , self.text] baseURL:self.URL];
    }
    else if (self.URL)
    {
        [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
    }
}

- (void) share:(id)_ {

    NSArray* items = @[ self.text ?: self.html ?: self.URL ?: @"" ];
    UIActivityViewController* activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    activityController.excludedActivityTypes = @[];
    [self presentViewController:activityController animated:YES completion:nil];
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
