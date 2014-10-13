//
//  MYCConnection.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCBackend : NSObject

// Returns an instance configured for testnet.
+ (instancetype) testnetBackend;

// Returns an instance configured for mainnet.
+ (instancetype) mainnetBackend;

// Returns YES if currently loading something.
- (BOOL) isActive;

// Fetches exchange rate for a given currency code.
- (void) fetchExchangeRateForCurrencyCode:(NSString*)currencyCode
                               completion:(void(^)(NSDecimalNumber* btcPrice, NSString* marketName, NSDate* date, NSString* nativeCurrencyCode, NSError* error))completionBlock;

@end
