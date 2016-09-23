//
//  MYCExchangeRate.m
//  Mycelium Wallet
//
//  Created by Andrew Toth on 2016-09-21.
//  Copyright © 2016 Mycelium. All rights reserved.
//

#import "MYCExchangeRate.h"

@implementation MYCExchangeRate

+ (id)exchangeRateFromDictionary:(NSDictionary *)dictionary {
    MYCExchangeRate * rate = [[MYCExchangeRate alloc] init];
    rate.currency = dictionary[@"currency"];
    rate.provider = dictionary[@"name"];
    id price = dictionary[@"price"];
    if ([price isKindOfClass:[NSDecimalNumber class]]) {
        rate.price = price;
    } else if ([price isKindOfClass:[NSNumber class]]) {
        rate.price = [NSDecimalNumber decimalNumberWithDecimal:((NSNumber *) price).decimalValue];
    } else {
        rate.price = [NSDecimalNumber zero];
    }
    rate.time = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"time"] doubleValue]];
    return rate;
}

@end
