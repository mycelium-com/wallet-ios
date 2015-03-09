//
//  BTCPriceSourceMycelium.m
//  Mycelium Wallet
//
//  Created by Pascal Edmond on 09/03/2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "BTCPriceSourceMycelium.h"
#import "MYCWallet.h"
#import "MYCBackend.h"

@implementation BTCPriceSourceMycelium

+ (void) load {
    [self registerPriceSource:[[self alloc] init]];
}

- (NSString*) name { return @"Mycelium"; }

- (NSArray*) currencyCodes { return @[@"USD", @"EUR", @"GBP", @"JPY", @"CHF"]; }

- (void) loadPriceForCurrency:(NSString*)currencyCode completionHandler:(void(^)(BTCPriceSourceResult* result, NSError* error))completionBlock
{
    [[MYCWallet currentWallet].backend loadExchangeRateForCurrencyCode:currencyCode completion:^(NSDecimalNumber *btcPrice, NSString *marketName, NSDate *date, NSString *nativeCurrencyCode, NSError *error) {
        if (completionBlock)
        {
            if (error)
            {
                completionBlock(nil, error);
            }
            else
            {
                BTCPriceSourceResult* result = [[BTCPriceSourceResult alloc] init];
                result.averageRate = btcPrice;
                result.currencyCode = currencyCode;
                result.nativeCurrencyCode = nativeCurrencyCode;
                result.date = [NSDate date];
                
                completionBlock(result, nil);
            }
        }
    }];
}

@end
