//
//  BTCPriceSourceMycelium.m
//  Mycelium Wallet
//
//  Created by Pascal Edmond on 09/03/2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "BTCPriceSourceMycelium.h"

@implementation BTCPriceSourceMycelium

+ (void) load {
    [self registerPriceSource:[[self alloc] init]];
}

- (NSString*) name { return @"Mycelium"; }

- (NSArray*) currencyCodes { return @[@"USD", @"EUR", @"GBP", @"JPY", @"CHF"]; }

// Returns a NSURLRequest to fetch the avg price.
- (NSURLRequest*) requestForCurrency:(NSString*)currencyCode {
    // curl  -k -X POST -H "Content-Type: application/json" -d '{"version":1,"currency":"USD"}' https://mws1.mycelium.com/wapi/wapi/queryExchangeRates
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://mws1.mycelium.com/wapi/wapi/queryExchangeRates"]];
    
    NSDictionary* payload = @{@"version":@1,
                              @"currency":currencyCode};
    NSError* jsonerror;
    NSData* jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonerror];
    if (jsonPayload)
    {
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:jsonPayload];
    }
    return request;
}

- (BTCPriceSourceResult*) resultFromParsedData:(id)parsedData currencyCode:(NSString*)currencyCode error:(NSError**)errorOut {
    //{
    //    "errorCode": 0,
    //    "r": {
    //        "currency": "USD",
    //        "exchangeRates": [{
    //            "name": "Bitstamp",
    //            "time": 1425903482661,
    //            "price": 279.75,
    //            "currency": "USD"
    //        }, {
    //            "name": "BitcoinAverage",
    //            "time": 1425903494435,
    //            "price": 279.83,
    //            "currency": "USD"
    //        }]
    //    }
    //}
    
    NSDictionary* result = parsedData[@"r"];
    NSArray* exchangeRates = result[@"exchangeRates"];
    
    for (NSDictionary* rate in exchangeRates)
    {
        if ([rate[@"name"] isEqualToString:@"BitcoinAverage"])
        {
            BTCPriceSourceResult* result = [[BTCPriceSourceResult alloc] init];
            result.averageRate = [NSDecimalNumber decimalNumberWithString:rate[@"price"]];
            result.currencyCode = currencyCode;
            result.nativeCurrencyCode = rate[@"currency"];
            result.date = [NSDate date];
            return result;
        }
    }
    
    return nil;
}


@end
