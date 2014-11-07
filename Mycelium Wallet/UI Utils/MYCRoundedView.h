//
//  MYCRoundedView.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 29.09.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

#define MYCRoundingDefaultRadius 4.0

IB_DESIGNABLE
@interface MYCRoundedView : UIView
@property(nonatomic) IBInspectable CGFloat borderRadius;
@property(nonatomic) IBInspectable UIColor* borderColor;
@property(nonatomic) IBInspectable CGFloat borderWidth;
@end

IB_DESIGNABLE
@interface MYCRoundedButton : UIButton
@property(nonatomic) IBInspectable CGFloat borderRadius;
@property(nonatomic) IBInspectable UIColor* borderColor;
@property(nonatomic) IBInspectable CGFloat borderWidth;
@end

IB_DESIGNABLE
@interface MYCRoundedTextField : UITextField
@property(nonatomic) IBInspectable CGFloat borderRadius;
@property(nonatomic) IBInspectable UIColor* borderColor;
@property(nonatomic) IBInspectable CGFloat borderWidth;
@end

IB_DESIGNABLE
@interface MYCRoundedTextView : UITextView
@property(nonatomic) IBInspectable CGFloat borderRadius;
@property(nonatomic) IBInspectable UIColor* borderColor;
@property(nonatomic) IBInspectable CGFloat borderWidth;
@end
