//
//  MYCTransactionDetails.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCTransactionDetails.h"
#import <CoreBitcoin/CoreBitcoin.h>

@implementation MYCTransactionDetails

- (id) initWithTxID:(NSString*)txid backupDictionary:(NSDictionary*)dict {
    if (self = [super init]) {
        id (^filterNSNull)(id) = ^(id objOrNil){
            if (!objOrNil) return (id)nil;
            if (objOrNil == [NSNull null]) return (id)nil;
            return objOrNil;
        };
        self.transactionID = txid;
        self.memo               = filterNSNull(dict[@"memo"]);
        self.recipient          = filterNSNull(dict[@"recipient"]);
        self.sender             = filterNSNull(dict[@"sender"]);
        self.paymentRequestData = BTCDataFromHex(filterNSNull(dict[@"payment_request"]));
        self.paymentACKData     = BTCDataFromHex(filterNSNull(dict[@"payment_ack"]));
        self.fiatAmount         = filterNSNull(dict[@"fiat_amount"]);
        self.fiatCode           = filterNSNull(dict[@"fiat_code"]);
    }
    return self;
}

- (void) fillBackupDictionary:(NSMutableDictionary*)dict {

    if (self.memo)                dict[@"memo"]            = self.memo;
    if (self.recipient)           dict[@"recipient"]       = self.recipient;
    if (self.sender)              dict[@"sender"]          = self.sender;
    if (self.paymentRequestData)  dict[@"payment_request"] = BTCHexFromData(self.paymentRequestData);
    if (self.paymentACKData)      dict[@"payment_ack"]     = BTCHexFromData(self.paymentACKData);
    if (self.fiatAmount)          dict[@"fiat_amount"]     = self.fiatAmount;
    if (self.fiatCode)            dict[@"fiat_code"]       = self.fiatCode;
}

- (NSString*) receiptMemo {
    if (self.paymentACKData.length > 0) {
        BTCPaymentACK* ack = [[BTCPaymentACK alloc] initWithData:self.paymentACKData];
        if (ack && ack.memo.length > 0) {
            return ack.memo;
        }
    }
#if DEBUG && 0
#warning FIXME: using test receipt instead of nil
    return @"Payment of 1 BTC for eleven tribbles accepted for processing. (This is test receipt.) Some long text always goes there to test limits of the text fields and cells.";
#endif
    return nil;
}

- (NSString*) transactionID {
    return BTCIDFromHash(self.transactionHash);
}

- (void) setTransactionID:(NSString *)transactionID {
    self.transactionHash = BTCHashFromID(transactionID);
}


#pragma mark - MYCDatabaseRecord


+ (id) primaryKeyName
{
    return @[MYCDatabaseColumn(transactionHash)];
}

+ (NSString *)tableName
{
    return @"MYCTransactionDetails";
}

+ (NSArray *)columnNames
{
    return @[MYCDatabaseColumn(transactionHash),
             MYCDatabaseColumn(memo),
             MYCDatabaseColumn(recipient),
             MYCDatabaseColumn(sender),
             MYCDatabaseColumn(paymentRequestData),
             MYCDatabaseColumn(paymentACKData),
             MYCDatabaseColumn(fiatAmount),
             MYCDatabaseColumn(fiatCode),
             ];
}

@end
