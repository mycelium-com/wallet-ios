//
//  MYCWebViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 07.11.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MYCWebViewController : UIViewController

@property(nonatomic) NSURL* URL;
@property(nonatomic) NSString* text;
@property(nonatomic) NSString* plainText;
@property(nonatomic) NSString* html;
@property(nonatomic) BOOL allowShare;

// Returns YES to ignore standard handling and direct all loading to -handleRequest.
// If this property is nil, but handleRequest is not, then handleRequest is always overriding default behaviour.
@property(nonatomic, strong) BOOL(^shouldHandleRequest)(MYCWebViewController* wvc, NSURLRequest* request, UIWebViewNavigationType navtype);

// Returns YES/NO to return from -webView:shouldStartLoadWithRequest:navigationType.
@property(nonatomic, strong) BOOL(^handleRequest)(MYCWebViewController* wvc, NSURLRequest* request, UIWebViewNavigationType navtype);

// Returns an array of items to share. Overrides default share behaviour that copies the text.
@property(nonatomic, strong) NSArray*(^itemsToShare)(MYCWebViewController* wvc);

- (void) share:(id)_;

@end
