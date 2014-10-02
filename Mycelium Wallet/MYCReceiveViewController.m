//
//  MYCReceiveViewController.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCReceiveViewController.h"

@interface MYCReceiveViewController ()

@end

@implementation MYCReceiveViewController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.title = NSLocalizedString(@"Receive Bitcoins", @"");
    }
    return self;
}


@end
