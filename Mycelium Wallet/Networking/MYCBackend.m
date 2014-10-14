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

- (void) fetchExchangeRateForCurrencyCode:(NSString*)currencyCode
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
               completion:^(NSDictionary* result, NSError* error){

                   if (!result)
                   {
                       if (completion) completion(nil, nil, nil, nil, error);
                       return;
                   }

                   if (![result[@"exchangeRates"] isKindOfClass:[NSArray class]])
                   {
                       if (completion) completion(nil, nil, nil, nil, [self formatError:@"Malformed result: 'exchangeRates' is not an array"]);
                       return;
                   }

                   if ([result[@"exchangeRates"] count] < 1)
                   {
                       if (completion) completion(nil, nil, nil, nil, [self dataError:@"No exchange rates returned"]);
                       return;
                   }

                   NSDictionary* rateDict = result[@"exchangeRates"][0];

                   if (![rateDict isKindOfClass:[NSDictionary class]])
                   {
                       if (completion) completion(nil, nil, nil, nil, [self formatError:@"Malformed result: exchange rate is not an dictionary"]);
                       return;
                   }

                   if (completion) completion([self ensureDecimalNumber:rateDict[@"price"]],
                                                       rateDict[@"name"],
                                                       [NSDate dateWithTimeIntervalSince1970:[rateDict[@"time"] doubleValue]],
                                                       rateDict[@"currency"],
                                                       nil);
               }];
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
//                    {
//                        "outPoint": "5630d46ba9be82a4061931be11b7ba3126068aad93873ef0f742d8f419961e63:1",
//                        "height": 300825,
//                        "value": 90000000,
//                        "script": "dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
//                        "isCoinBase": false
//                    },
//                    {
//                        "outPoint": "6a73582d58fcbf6345ddb5d59daaf74776303e425237a7e5d9e683495187dc85:0",
//                        "height": 300825,
//                        "value": 91000000,
//                        "script": "dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
//                        "isCoinBase": false
//                    },
//                    {
//                        "outPoint": "92082fa94ae0e5b97b8f1b5a15c5f3f55648394f576755235bb2c2389d906f1d:0",
//                        "height": 300766,
//                        "value": 100000000,
//                        "script": "dqkUINSkoZDqj3qXkFlUtWwcl398DkaIrA==",
//                        "isCoinBase": false
//                    }]
//    }
//}


#pragma mark - Utils


- (void) makeJSONRequest:(NSString*)name payload:(NSDictionary*)payload completion:(void(^)(NSDictionary* result, NSError* error))completion
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

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        NSDictionary* result = [self handleReceivedJSON:data response:response error:error failure:^(NSError* error2){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.pendingTasksCount--;
                if (completion) completion(nil, error2);
            });
        }];

        // Generic errors are already handled and reported above.
        if (!result) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.pendingTasksCount--;
            if (completion) completion(result, nil);
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
    return [NSError errorWithDomain:@"com.mycelium.wallet" code:1 userInfo: errorString ? @{NSLocalizedDescriptionKey: errorString} : nil];
}

- (NSError*) dataError:(NSString*)errorString
{
    return [NSError errorWithDomain:@"com.mycelium.wallet" code:2 userInfo: errorString ? @{NSLocalizedDescriptionKey: errorString} : nil];
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
        failureBlock(error ?: [NSError errorWithDomain:@"com.mycelium.wallet" code:0 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Non-HTTP response received.", @"MYC")}]);
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
        if ([dict[@"errorCode"] integerValue] == 0 && dict[@"r"])
        {
            return dict[@"r"];
        }
        else
        {
            MYCLog(@"MYCBackend: received errorCode %@: %@", dict[@"errorCode"], dict);
            NSError* apiError = [NSError errorWithDomain:@"com.mycelium.wallet"
                                                     code:[dict[@"errorCode"] integerValue]
                                                 userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Mycelium server responded with error %@", @""), dict[@"errorCode"]]
                                                            }];

            failureBlock(apiError);
            return nil;
        }
    }

    MYCLog(@"MYCBackend: received HTTP code %ld: %@", (long)httpResponse.statusCode, dict[@"localizedError"] ?: dict[@"error"] ?: @"Server Error");

    NSError* httpError = [NSError errorWithDomain:@"com.mycelium.wallet"
                                            code:httpResponse.statusCode
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey: dict[@"localizedError"] ?: dict[@"error"] ?: @"Server Error",
                                                   @"debugMessage": dict[@"error"] ?: @"unknown error from backend",
                                                   }];

    failureBlock(httpError);
    return nil;
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
