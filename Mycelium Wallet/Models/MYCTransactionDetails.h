//
//  MYCTransactionDetails.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 28.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCDatabaseRecord.h"

@interface MYCTransactionDetails : MYCDatabaseRecord

- (id) initWithTxID:(NSString*)txid backupDictionary:(NSDictionary*)dict;

- (void) fillBackupDictionary:(NSMutableDictionary*)dict;

@property(nonatomic) NSString* transactionID;
@property(nonatomic) NSData*   transactionHash;
@property(nonatomic) NSString* memo;
@property(nonatomic) NSString* recipient;
@property(nonatomic) NSString* sender;
@property(nonatomic) NSData*   paymentRequestData;
@property(nonatomic) NSData*   paymentACKData;
@property(nonatomic) NSString* fiatAmount;
@property(nonatomic) NSString* fiatCode;

@property(nonatomic, readonly) NSString* receiptMemo;

@end
