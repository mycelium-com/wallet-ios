//
//  MYCSendViewController.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MYCWalletAccount;
@interface MYCSendViewController : UIViewController

// Called when user cancels or sends money.
@property(nonatomic,copy) void(^completionBlock)(BOOL sent);

// Default address where to send funds.
@property(nonatomic) BTCAddress* defaultAddress;

// If not nil, overrides account change address.
@property(nonatomic) BTCAddress* changeAddress;

// Label to explain this address.
@property(nonatomic) NSString* defaultAddressLabel;

// If not zero, placed as a default amount in the amount field.
@property(nonatomic) BTCSatoshi defaultAmount;

// If YES, default amount is set to use all funds.
@property(nonatomic) BOOL prefillAllFunds;



// Either set the account, or...
@property(nonatomic) MYCWalletAccount* account;

// ... a list of utxos and a single private key to sign them.
@property(nonatomic) NSArray* unspentOutputs;
@property(nonatomic) BTCKey* key;

@end
