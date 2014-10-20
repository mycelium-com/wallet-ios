//
//  MYCConnection.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 01.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCBackend.h"

@interface MYCBackend () <NSURLSessionDelegate>

// List of NSURL endpoints to which this client may connect.
@property(atomic) NSArray* endpointURLs;

// SHA-1 fingerprint of the SSL certificate to prevent MITM attacks.
// E.g. B3:42:65:33:40:F5:B9:1B:DA:A2:C8:7A:F5:4C:7C:5D:A9:63:C4:C3.
@property(atomic) NSData* SSLFingerprint;

// Version of the API to be used.
@property(atomic) NSNumber* version;

// URL session used to issue requests
@property(atomic) NSURLSession* session;

// Currently used endpoint URL.
@property(atomic) NSURL* currentEndpointURL;

@property(atomic) int pendingTasksCount;

@end

@implementation MYCBackend

// Returns an instance configured for mainnet.
+ (instancetype) mainnetBackend
{
    static MYCBackend* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MYCBackend alloc] init];
        instance.version = @(1);
        instance.endpointURLs = @[
                                  [NSURL URLWithString:@"https://mws1.mycelium.com/wapi"],
                                  [NSURL URLWithString:@"https://188.40.12.226/wapi"],
                                  [NSURL URLWithString:@"https://mws2.mycelium.com/wapi"],
                                  [NSURL URLWithString:@"https://88.198.17.7/wapi"],
                                  ];
        instance.SSLFingerprint = BTCDataWithHexString([@"B3:42:65:33:40:F5:B9:1B:DA:A2:C8:7A:F5:4C:7C:5D:A9:63:C4:C3" stringByReplacingOccurrencesOfString:@":" withString:@""]);
    });
    return instance;
}


// Returns an instance configured for testnet.
+ (instancetype) testnetBackend
{
    static MYCBackend* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MYCBackend alloc] init];
        instance.version = @(1);
        instance.endpointURLs = @[
                        [NSURL URLWithString:@"https://node3.mycelium.com/wapitestnet"],
                        [NSURL URLWithString:@"https://144.76.165.115/wapitestnet"],
                        ];
        instance.SSLFingerprint = BTCDataWithHexString([@"E5:70:76:B2:67:3A:89:44:7A:48:14:81:DF:BD:A0:58:C8:82:72:4F" stringByReplacingOccurrencesOfString:@":" withString:@""]);
    });
    return instance;
}

- (id) init
{
    if (self = [super init])
    {
        NSURLSessionConfiguration* config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 10.0;
        config.timeoutIntervalForResource = 120.0;
        config.HTTPMaximumConnectionsPerHost = 1;
        config.protocolClasses = @[];
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

// Returns YES if currently loading something.
- (BOOL) isActive
{
    return self.pendingTasksCount > 0;
}

- (void) loadExchangeRateForCurrencyCode:(NSString*)currencyCode
                               completion:(void(^)(NSDecimalNumber* btcPrice, NSString* marketName, NSDate* date, NSString* nativeCurrencyCode, NSError* error))completion
{
    NSParameterAssert(currencyCode);

//    curl  -k -X POST -H "Content-Type: application/json" -d '{"version":1,"currency":"USD"}' https://144.76.165.115/wapitestnet/wapi/queryExchangeRates
//    {
//        "errorCode": 0,
//        "r": {
//            "currency": "USD",
//            "exchangeRates": [{
//                "name": "Bitstamp",
//                "time": 1413196507900,
//                "price": 378.73,
//                "currency": "USD"
//            },
//            {
//                "name": "BTC-e",
//                "time": 1413196472250,
//                "price": 370.882,
//                "currency": "USD"
//            },

    [self makeJSONRequest:@"queryExchangeRates"
                  payload:@{ @"version": self.version, @"currency": currencyCode ?: @"USD" }
                 template:@{@"currency": @"USD",
                            @"exchangeRates": @[@{
                                @"name":     @"Bitstamp",
                                @"time":     @1413196507900,
                                @"price":    @378.12,
                                @"currency": @"USD"
                            }]}
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       if (completion) completion(nil, nil, nil, nil, error);
                       return;
                   }

                   if ([result[@"exchangeRates"] count] < 1)
                   {
                       if (completion) completion(nil, nil, nil, nil, [self dataError:@"No exchange rates returned"]);
                       return;
                   }

                   // Taking the first exchange rate for now. Later we'll support switch in the settings.
                   NSDictionary* rateDict = [result[@"exchangeRates"] firstObject];

                   if (completion) completion([self ensureDecimalNumber:rateDict[@"price"]],
                                                       rateDict[@"name"],
                                                       [NSDate dateWithTimeIntervalSince1970:[rateDict[@"time"] doubleValue]],
                                                       rateDict[@"currency"],
                                                       nil);
               }];
}


// Fetches unspent outputs for given addresses (BTCAddress instances)
- (void) loadUnspentOutputsForAddresses:(NSArray*)addresses completion:(void(^)(NSArray* outputs, NSInteger height, NSError* error))completion
{
    NSParameterAssert(addresses);

    if (addresses.count == 0)
    {
        if (completion) completion(@[], 0, nil);
        return;
    }

    //
    //curl  -k -X POST -H "Content-Type: application/json" -d '{"version":1,"addresses":["miWYetn5RRjatKmHgNm6VGYT2jivUjZv5y"]}' https://144.76.165.115/wapitestnet/wapi/queryUnspentOutputs
    //
    //{
    //    "errorCode": 0,
    //    "r": {
    //        "height": 300825,
    //        "unspent": [{
    //            "outPoint": "2c2cea628728ed8c6345a0d8bc172dd301104707ab1057a0309984b5a212dd98:0",
    //            "height": 300766,
    //            "value": 100000000,
    //            "script": "dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
    //            "isCoinBase": false
    //        },
    //        {
    //            "outPoint": "5630d46ba9be82a4061931be11b7ba3126068aad93873ef0f742d8f419961e63:1",
    //            "height": 300825,
    //            "value": 90000000,
    //            "script": "dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
    //            "isCoinBase": false
    //        },
    //    }
    //}

    [self makeJSONRequest:@"queryUnspentOutputs"
                  payload:@{ @"version": self.version,
                             @"addresses": [addresses valueForKeyPath:@"publicAddress.base58String"] }
                 template:@{
                            @"height": @300825,
                            @"unspent": @[@{
                                              @"outPoint":   @"2c2cea628728ed8c6345a0d8bc172dd301104707ab1057a0309984b5a212dd98:0",
                                              @"height":     @300766,
                                              @"value":      @100000000,
                                              @"script":     @"dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
                                              @"isCoinBase": @NO }]}
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       if (completion) completion(nil, 0, error);
                       return;
                   }

                   // Get the current block height.
                   NSInteger height = [result[@"height"] integerValue];

                   NSMutableArray* unspentOutputs = [NSMutableArray array];

                   for (NSDictionary* dict in result[@"unspent"])
                   {
                       // "outPoint": "92082fa94ae0e5b97b8f1b5a15c5f3f55648394f576755235bb2c2389d906f1d:0",
                       // "height": 300766,
                       // "value": 100000000,
                       // "script": "dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
                       // "isCoinBase": false

                       NSArray* txHashAndIndex = [dict[@"outPoint"] componentsSeparatedByString:@":"];

                       if (txHashAndIndex.count != 2)
                       {
                           if (completion) completion(nil, 0, [self formatError:@"Malformed result: 'outPoint' is a string with a single ':' separator"]);
                           return;
                       }

                       NSData* scriptData = [[NSData alloc] initWithBase64EncodedString:dict[@"script"] options:0];

                       if (!scriptData)
                       {
                           if (completion) completion(nil, 0, [self formatError:@"Malformed result: 'script' is not a valid Base64 string"]);
                           return;
                       }

                       // tx hash is sent reversed, but we store the true hash
                       NSData* txhash = BTCReversedData(BTCDataWithHexString(txHashAndIndex[0]));

                       if (!txhash || txhash.length != 32)
                       {
                           if (completion) completion(nil, 0, [self formatError:@"Malformed result: 'outPoint' does not contain a correct reversed hex 256-bit transaction hash."]);
                           return;
                       }

                       BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] init];

                       txout.value = [dict[@"value"] longLongValue];
                       txout.script = [[BTCScript alloc] initWithData:scriptData];
                       txout.transactionHash = txhash;

                       [unspentOutputs addObject:txout];
                   }

                   if (completion) completion(unspentOutputs, height, nil);
               }];
}


// Fetches the latest transaction ids for given addresses (BTCAddress instances).
// Results include both transactions spending and receiving to the given addresses.
// Default limit is 1000.
- (void) loadTransactionsForAddresses:(NSArray*)addresses completion:(void(^)(NSArray* txids, NSInteger height, NSError* error))completion
{
    [self loadTransactionsForAddresses:addresses limit:1000 completion:completion];
}

- (void) loadTransactionsForAddresses:(NSArray*)addresses limit:(NSUInteger)limit completion:(void(^)(NSArray* txids, NSInteger height, NSError* error))completion
{
    NSParameterAssert(addresses);

    if (addresses.count == 0)
    {
        if (completion) completion(@[], 0, nil);
        return;
    }

    // curl -k -X POST -H "Content-Type: application/json" -d '{"version":1,"addresses":["miWYetn5RRjatKmHgNm6VGYT2jivUjZv5y"],"limit":1000}' https://144.76.165.115/wapitestnet/wapi/queryTransactionInventory
    // {"errorCode":0,
    //     "r":{
    //         "height":301943,
    //         "txIds":[
    //                  "9857dc366848ffb8d4616631d6fa1bcb139ffd11834feb6e3520f9febd17ac79",
    //                  "3f7a173870c3c3b2914fc3228770863ae0aba7f3960774fb6ced88b915610262",
    //                  "3635eee25fb237c57090fda60d3a2f33707201a941d281bc663e540ef1eb1f0b",
    //                  "5630d46ba9be82a4061931be11b7ba3126068aad93873ef0f742d8f419961e63",
    //                  "6a73582d58fcbf6345ddb5d59daaf74776303e425237a7e5d9e683495187dc85",
    //                  "92082fa94ae0e5b97b8f1b5a15c5f3f55648394f576755235bb2c2389d906f1d",
    //                  "2c2cea628728ed8c6345a0d8bc172dd301104707ab1057a0309984b5a212dd98"
    //          ]
    //      }
    //  }

    [self makeJSONRequest:@"queryTransactionInventory"
                  payload:@{ @"version": self.version,
                             @"addresses": [addresses valueForKeyPath:@"publicAddress.base58String"] }
                 template:@{@"height": @301943,
                            @"txIds":@[
                               @"9857dc366848ffb8d4616631d6fa1bcb139ffd11834feb6e3520f9febd17ac79",
                               @"3f7a173870c3c3b2914fc3228770863ae0aba7f3960774fb6ced88b915610262",
                               @"3635eee25fb237c57090fda60d3a2f33707201a941d281bc663e540ef1eb1f0b",
                            ]}
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       if (completion) completion(nil, 0, error);
                       return;
                   }

                   // Get the current block height.
                   NSInteger height = [result[@"height"] integerValue];

                   NSArray* txids = result[@"txIds"] ?: @[];

                   if (completion) completion(txids, height, nil);
               }];
}



// Checks status of the given transaction IDs and returns an array of dictionaries.
// Each dictionary is of this format: {@"txid": @"...", @"found": @YES/@NO, @"height": @123, @"date": NSDate }.
// * `txid` key corresponds to the transaction ID in the array of `txids`.
// * `found` contains YES if transaction is found and NO otherwise.
// * `height` contains -1 for unconfirmed transaction and block height at which it is included.
// * `date` contains time when transaction is recorded or noticed.
// In case of error, `dicts` is nil and `error` contains NSError object.
- (void) loadStatusForTransactions:(NSArray*)txids completion:(void(^)(NSArray* dicts, NSError* error))completion
{
    NSParameterAssert(txids);

    if (txids.count == 0)
    {
        if (completion) completion(@[], nil);
        return;
    }

    // curl   -k -X POST -H "Content-Type: application/json" -d '{"txIds":["1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198"]}' https://144.76.165.115/wapitestnet/wapi/checkTransactions
    // {"errorCode":0,
    //   "r":{
    //       "transactions":[
    //           {"txid":"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198",
    //            "found":true,
    //            "height":280489,
    //            "time":1410965947}
    //        ]
    //    }}

    [self makeJSONRequest:@"checkTransactions"
                  payload:@{ @"version": self.version,
                             @"txIds": txids }
                 template:@{
                            @"transactions":@[
                                @{@"txid":   @"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198",
                                  @"found":  @YES,
                                  @"height": @280489,
                                  @"time":   @1410965947}
                            ]}
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       if (completion) completion(nil, error);
                       return;
                   }

                   NSMutableArray* resultDicts = [NSMutableArray array];

                   for (NSDictionary* dict in result[@"transactions"])
                   {
                       NSTimeInterval ts = [dict[@"time"] doubleValue];
                       NSDate* date = [NSDate dateWithTimeIntervalSince1970:ts];
                       [resultDicts addObject:@{
                                          @"txid":   dict[@"txid"] ?: @"",
                                          @"found":  dict[@"found"] ?: @NO,
                                          @"height": dict[@"height"] ?: @(-1),
                                          @"date":   date,
                                          @"time":   date, // just in case
                                          }];
                   }
                   
                   if (completion) completion(resultDicts, nil);
               }];
}



// Loads actual transactions (BTCTransaction instances) for given txids.
// Each transaction contains blockHeight property (-1 = unconfirmed) and blockDate property.
//
// See WapiResponse<GetTransactionsResponse> getTransactions(GetTransactionsRequest request);
- (void) loadTransactions:(NSArray*)txids completion:(void(^)(NSArray* dicts, NSError* error))completion
{
    NSParameterAssert(txids);

    if (txids.count == 0)
    {
        if (completion) completion(@[], nil);
        return;
    }

    // curl -k -X POST -H "Content-Type: application/json" -d '{"version":1,"txIds":["1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198"]}' https://144.76.165.115/wapitestnet/wapi/getTransactions
    // {"errorCode":0,
    //  "r":{
    //       "transactions":[{
    //            "txid":"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198",
    //            "height":280489,
    //            "time":1410965947,
    //            "binary":"AQAAAAHqHGsQSIun5hjDDWm7iFMwm85xNLt+HBfI3LS3uQHnSQEAAABrSDBFAiEA6rlGk4wgIL3TvC2YHK4XiBW2vPYg82iCgnQi+YOUwqACIBpzVk756/07SRORT50iRZvEGUIn3Lh3bhaRE1aUMgZZASECDFl9wEYDCvB1cJY6MbsakfKQ9tbQhn0eH9C//RI2iE//////ApHwGgAAAAAAGXapFIzWtPXZR7lk8RtvE0FDMHaLtsLCiKyghgEAAAAAABl2qRSuzci59wapXUEzwDzqKV9nIaqwz4isAAAAAA=="
    //           }]
    // }}

    [self makeJSONRequest:@"getTransactions"
                  payload:@{ @"version": self.version,
                             @"txIds": txids }
                 template:@{
                            @"transactions":@[
                                    @{@"txid":   @"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198",
                                      @"height": @280489,
                                      @"time":   @1410965947,
                                      @"binary": @"base64string"}
                                    ]}
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       if (completion) completion(nil, error);
                       return;
                   }

                   NSMutableArray* txs = [NSMutableArray array];

                   BOOL parseFailure = NO;
                   for (NSDictionary* dict in result[@"transactions"])
                   {
                       NSTimeInterval ts = [dict[@"time"] doubleValue];
                       NSDate* blockDate = ts > 0.0 ? [NSDate dateWithTimeIntervalSince1970:ts] : nil;
                       NSInteger blockHeight = [dict[@"height"] intValue];

                       NSData* txdata = [[NSData alloc] initWithBase64EncodedString:dict[@"binary"] options:0];

                       if (!txdata)
                       {
                           MYCLog(@"MYCBackend loadTransactions: malformed Base64 encoding for tx data: %@", dict);
                           parseFailure = YES;
                       }
                       else
                       {
                           BTCTransaction* tx = [[BTCTransaction alloc] initWithData:txdata];
                           
                           if (!tx)
                           {
                               MYCLog(@"MYCBackend loadTransactions: malformed transaction data (can't make BTCTransaction): %@", dict);
                               parseFailure = YES;
                           }
                           else
                           {
                               [txs addObject:tx];
                           }
                       }
                   }

                   if (parseFailure && txs.count == 0)
                   {
                       if (completion) completion(nil, [self formatError:[NSString stringWithFormat:NSLocalizedString(@"Cannot parse any transaction returned for txids %@", @""), txids]]);
                       return;
                   }

                   if (completion) completion(txs, nil);
               }];
}



// Broadcasts the transaction and returns appropriate status.
// See comments on MYCBackendBroadcastStatus above.
// Result: {"errorCode":0,"r":{"success":true,"txid":"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198"}}
// Result: {"errorCode":99}
// WapiResponse<BroadcastTransactionResponse> broadcastTransaction(BroadcastTransactionRequest request);
- (void) broadcastTransaction:(BTCTransaction*)tx completion:(void(^)(MYCBroadcastStatus status, NSError* error))completion
{
    NSParameterAssert(tx);

    // curl  -k -X POST -H "Content-Type: application/json" -d '{"version":1,"rawTransaction":"AQAAAAHqHGsQSIun5hjDDWm7iFMwm85xNLt+HBfI3LS3uQHnSQEAAABrSDBFAiEA6rlGk4wgIL3TvC2YHK4XiBW2vPYg82iCgnQi+YOUwqACIBpzVk756/07SRORT50iRZvEGUIn3Lh3bhaRE1aUMgZZASECDFl9wEYDCvB1cJY6MbsakfKQ9tbQhn0eH9C//RI2iE//////ApHwGgAAAAAAGXapFIzWtPXZR7lk8RtvE0FDMHaLtsLCiKyghgEAAAAAABl2qRSuzci59wapXUEzwDzqKV9nIaqwz4isAAAAAA=="}' https://144.76.165.115/wapitestnet/wapi/broadcastTransaction
    // Result: {"errorCode":0,"r":{"success":true,"txid":"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198"}}
    // Result: {"errorCode":99}

    NSData* txdata = tx.data;

    NSAssert(txdata, @"sanity check");

    NSString* base64tx = [txdata base64EncodedStringWithOptions:0];

    NSAssert(base64tx, @"sanity check");

    if (!base64tx)
    {
        if (completion) completion(MYCBroadcastStatusBadTransaction, nil);
        return;
    }

    [self makeJSONRequest:@"broadcastTransaction"
                  payload:@{ @"version": self.version,
                             @"rawTransaction": base64tx }
                 template:@{
                            @"success":@YES,
                            @"txid": @"1513b9b160ef6b20bbb06b7bb6e7364e58e27e1df53f8f7e12e67f17d46ad198"
                            }
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       // Special case: bad transaction yields 99 error.
                       if ([error.domain isEqual:MYCErrorDomain] && error.code == 99)
                       {
                           if (completion) completion(MYCBroadcastStatusBadTransaction, error);
                           return;
                       }
                       if (completion) completion(MYCBroadcastStatusFailure, error);
                       return;
                   }

                   BOOL success = [result[@"success"] boolValue];

                   if (!success)
                   {
                       // Unknown failure
                       if (completion) completion(MYCBroadcastStatusFailure, error);
                       return;
                   }

                   if (completion) completion(MYCBroadcastStatusSuccess, error);
               }];
}






#pragma mark - Utils



- (void) makeJSONRequest:(NSString*)name payload:(NSDictionary*)payload template:(id)template completion:(void(^)(NSDictionary* result, NSError* error))completion
{
    self.pendingTasksCount++;

    self.currentEndpointURL = self.endpointURLs.firstObject;

    NSMutableURLRequest* req = [self requestWithName:name];

    if (payload)
    {
        NSError* jsonerror;
        NSData* jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonerror];
        if (!jsonPayload)
        {
            self.pendingTasksCount--;
            if (completion) completion(nil, jsonerror);
            return;
        }

        [req setHTTPMethod:@"POST"];
        [req setHTTPBody:jsonPayload];
    }

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *networkError) {

        NSDictionary* result = [self handleReceivedJSON:data response:response error:networkError failure:^(NSError* jsonError){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.pendingTasksCount--;
                if (completion) completion(nil, jsonError);
            });
        }];

        // Generic errors are already handled and reported above.
        if (!result) return;

        NSError* formatError = nil;
        BOOL valid = NO;

        // Validate the template provided
        valid = [self validatePlist:result matchingTemplate:template error:&formatError];
        if (!valid) result = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.pendingTasksCount--;
            if (completion) completion(result, formatError);
        });

    }] resume];
}

- (NSMutableURLRequest*) requestWithName:(NSString*)name
{
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/wapi/%@", self.currentEndpointURL.absoluteString, name]];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];

    // Set the content defaults
    [request setValue:@"gzip,deflate" forHTTPHeaderField:@"Accept-Encoding"];
    NSString* locale = [[[NSLocale currentLocale] localeIdentifier] stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    [request setValue:locale forHTTPHeaderField:@"Accept-Language"];

    // Set the JSON defaults.
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"Accept-Charset"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; // default, can be overriden later

    return request;
}

- (NSError*) formatError:(NSString*)errorString
{
    return [NSError errorWithDomain:MYCErrorDomain code:1 userInfo: errorString ? @{NSLocalizedDescriptionKey: errorString} : nil];
}

- (NSError*) dataError:(NSString*)errorString
{
    return [NSError errorWithDomain:MYCErrorDomain code:2 userInfo: errorString ? @{NSLocalizedDescriptionKey: errorString} : nil];
}

- (NSDecimalNumber*) ensureDecimalNumber:(NSNumber*)num
{
    if ([num isKindOfClass:[NSDecimalNumber class]])
    {
        return (id)num;
    }
    return [NSDecimalNumber decimalNumberWithDecimal:num.decimalValue];
}


// Generic error handling. Either returns a non-nil value or calls a block with error.
- (NSDictionary*) handleReceivedJSON:(NSData*)data response:(NSURLResponse*)response error:(NSError*)error failure:(void(^)(NSError*))failureBlock
{
    if (!data)
    {
        // TODO: make this error more readable for user
        failureBlock(error);
        return nil;
    }

    // Timeout special case: received an empty response
    if (data.length == 0 && response == nil && error)
    {
        MYCLog(@"Timeout-like error: %@", error);
        failureBlock(error);
        return nil;
    }

    if (![response isKindOfClass:[NSHTTPURLResponse class]])
    {
        MYCLog(@"EXPECTED HTTP RESPONSE, GOT THIS: %@ Error: %@", response, error);
        failureBlock(error ?: [NSError errorWithDomain:MYCErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-HTTP response received.", @"MYC")}]);
        return nil;
    }

    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;

    NSError* jsonerror = nil;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonerror];

    if (!dict)
    {
        // TODO: make this error more readable for user
        MYCDebug(NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];)
        MYCLog(@"EXPECTED JSON, GOT THIS: %@ (%@) [http status code: %d, url: %@] response headers: %@", string, data, (int)httpResponse.statusCode, httpResponse.URL, httpResponse.allHeaderFields);
        failureBlock(jsonerror);
        return nil;
    }

    if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299)
    {
        // Check if response is correctly formatted with "errorCode" and "r" slots present.
        NSError* formatError = nil;
        BOOL validFormat = [self validatePlist:dict matchingTemplate:@{@"errorCode": @0, @"r": @{ }} error:&formatError];
        if (!validFormat)
        {
            failureBlock(formatError);
            return nil;
        }

        if ([dict[@"errorCode"] integerValue] == 0 && dict[@"r"])
        {
            return dict[@"r"];
        }
        else
        {
            MYCLog(@"MYCBackend: received errorCode %@: %@", dict[@"errorCode"], dict);
            NSError* apiError = [NSError errorWithDomain:MYCErrorDomain
                                                     code:[dict[@"errorCode"] integerValue]
                                                 userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Mycelium server responded with error %@", @""), dict[@"errorCode"]]
                                                            }];

            failureBlock(apiError);
            return nil;
        }
    }

    MYCLog(@"MYCBackend: received HTTP code %ld: %@", (long)httpResponse.statusCode, dict[@"localizedError"] ?: dict[@"error"] ?: @"Server Error");

    NSError* httpError = [NSError errorWithDomain:NSURLErrorDomain
                                            code:httpResponse.statusCode
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey: dict[@"localizedError"] ?: dict[@"error"] ?: @"Server Error",
                                                   @"debugMessage": dict[@"error"] ?: @"unknown error from backend",
                                                   }];

    failureBlock(httpError);
    return nil;
}





#pragma mark - Validation Utils





- (BOOL) validatePlist:(id)plist matchingTemplate:(id)template error:(NSError**)errorOut
{
    return [self validatePlist:plist matchingTemplate:template error:errorOut path:@""];
}

- (BOOL) validatePlist:(id)plist matchingTemplate:(id)template error:(NSError**)errorOut path:(NSString*)path
{
    // No template - all values are okay. This is used e.g. by empty array (arbitrary data is okay)
    if (!template) return YES;

    if (!plist)
    {
        if (errorOut) *errorOut = [self dataError:NSLocalizedString(@"Missing data", @"")];
        return NO;
    }

    if (![self plist:plist compatibleWithTypeOfPlist:template])
    {
        if (errorOut)
        {
            NSString* msg = [NSString stringWithFormat:NSLocalizedString(@"JSON entity (%@) is not type-compatible with expected template (%@): %@ <=> %@ (json%@)",@""),
                             [plist class], [template class], plist, template, path];
            *errorOut = [self formatError:msg];
        }
        return NO;
    }

    if ([plist isKindOfClass:[NSDictionary class]])
    {
        // Do not drill down the items if template does not specify any item value.
        if ([template count] == 0) return YES;

        // If we compare with dict, we accept any keys not mentioned in the template
        // and validate types of keys mentioned in the template
        for (id key in plist)
        {
            id templateItem = [template objectForKey:key];
            id item = [plist objectForKey:key];
            BOOL result = [self validatePlist:item matchingTemplate:templateItem error:errorOut path:[path stringByAppendingFormat:@"[@\"%@\"]", key]];
            if (!result) return NO;
        }
        return YES;
    }
    else if ([plist isKindOfClass:[NSArray class]])
    {
        // Do not drill down the items if template does not specify any item value.
        if ([template count] == 0) return YES;

        // Every item must be type compatible with the first item in the template.
        // If template is empty, no checking is required.
        id firstItemTemplate = [template firstObject]; // can be nil, then any item is accepted.
        int i = 0;
        for (id item in plist)
        {
            BOOL result = [self validatePlist:item matchingTemplate:firstItemTemplate error:errorOut path:[path stringByAppendingFormat:@"[%d]", i]];
            if (!result) return NO;
            i++;
        }
        return YES;
    }
    else
    {
        // Type-compatible scalar values (strings, numbers, dates, data objects).
        return YES;
    }
}

// This allows to compare immutable classes with mutable counterparts and handle unexpected private subclasses.
- (BOOL) plist:(id)a compatibleWithTypeOfPlist:(id)b
{
    if (!a || !b) return NO;
    if ([a class] == [b class]) return YES;
    if ([a isKindOfClass:[NSNumber class]]     && [b isKindOfClass:[NSNumber class]])     return YES;
    if ([a isKindOfClass:[NSString class]]     && [b isKindOfClass:[NSString class]])     return YES;
    if ([a isKindOfClass:[NSDictionary class]] && [b isKindOfClass:[NSDictionary class]]) return YES;
    if ([a isKindOfClass:[NSArray class]]      && [b isKindOfClass:[NSArray class]])      return YES;
    if ([a isKindOfClass:[NSDate class]]       && [b isKindOfClass:[NSDate class]])       return YES;
    if ([a isKindOfClass:[NSData class]]       && [b isKindOfClass:[NSData class]])       return YES;
    return NO;
}







#pragma mark - NSURLSessionDelegate


- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] &&
        self.SSLFingerprint)
    {
        // Certificate is invalid unless proven valid.
        disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;

        // Check that the hostname matches.
        if ([challenge.protectionSpace.host isEqualToString:self.currentEndpointURL.host])
        {
            // Check the sha1 fingerprint of the certificate here.
            // We may have several certificates, only one is enough to match.
            SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
            CFIndex crtCount = SecTrustGetCertificateCount(serverTrust);
            for (CFIndex i = 0; i < crtCount; i++)
            {
                SecCertificateRef cert = SecTrustGetCertificateAtIndex(serverTrust, i);
                NSData* certData = CFBridgingRelease(SecCertificateCopyData(cert));
                if ([BTCSHA1(certData) isEqual:self.SSLFingerprint])
                {
                    disposition = NSURLSessionAuthChallengeUseCredential;
                    credential = [NSURLCredential credentialForTrust:serverTrust];
                    break;
                }
            }
        }
    }
    if (completionHandler) completionHandler(disposition, credential);
}

@end
