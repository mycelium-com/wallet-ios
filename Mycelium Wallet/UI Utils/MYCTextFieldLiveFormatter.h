//
//  MYCTextFieldFormatter.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 23.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCTextFieldLiveFormatter : NSObject <UITextFieldDelegate>

@property(nonatomic) UITextField* textField;
@property(nonatomic) NSNumberFormatter* formatter;

- (id) initWithTextField:(UITextField*)textField numberFormatter:(NSNumberFormatter*)formatter;

@end
