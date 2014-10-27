//
//  MYCOutgoingTransaction.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 27.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCOutgoingTransaction.h"

@interface MYCOutgoingTransaction ()
@property(nonatomic) NSString* dataHex; // MYCDebugHexDatabaseFields
@end

@implementation MYCOutgoingTransaction

- (BTCTransaction*) transaction
{
    return [[BTCTransaction alloc] initWithData:self.data];
}

- (void) setTransaction:(BTCTransaction *)transaction
{
    self.data = transaction.data;
    self.transactionHash = transaction.transactionHash;
}

- (NSString*) transactionID
{
    return BTCTransactionIDFromHash(self.transactionHash);
}

- (NSString*) dataHex
{
    return BTCHexStringFromData(self.data);
}


#pragma mark - MYCDatabaseRecord



+ (id) primaryKeyName
{
    return @"id";
}

+ (NSString *)tableName
{
    return @"MYCOutgoingTransactions";
}

+ (NSArray *)columnNames
{
    return @[
             @"id",
             MYCDatabaseColumn(transactionHash),
#if MYCDebugHexDatabaseFields
             MYCDatabaseColumn(transactionID),
             MYCDatabaseColumn(dataHex),
#endif
             MYCDatabaseColumn(data),
             ];
}


@end
