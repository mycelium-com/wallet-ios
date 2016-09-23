//
//  MYCExchangeRate.h
//  Mycelium Wallet
//
//  Created by Andrew Toth on 2016-09-21.
//  Copyright © 2016 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCExchangeRate : NSObject

+ (id)exchangeRateFromDictionary:(NSDictionary *)dictionary;

@property(nonatomic) NSString * provider;
@property(nonatomic) NSString * currency;
@property(nonatomic) NSDate * time;
@property(nonatomic) NSDecimalNumber * price;

@end
