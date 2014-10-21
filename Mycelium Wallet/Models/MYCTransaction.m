//
//  MYCTransaction.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCTransaction.h"

@interface MYCTransaction ()
@property(nonatomic) NSTimeInterval timestamp;
@end

@implementation MYCTransaction

- (BTCTransaction*) transaction
{
    BTCTransaction* tx = [[BTCTransaction alloc] initWithData:self.data];
    tx.blockDate = self.date;
    tx.blockHeight = self.blockHeight;
    return tx;
}

- (void) setTransaction:(BTCTransaction *)transaction
{
    self.data = transaction.data;
    self.date = transaction.blockDate;
    self.blockHeight = transaction.blockHeight;
    self.transactionHash = transaction.transactionHash;
}

- (NSDate *) date
{
    if (self.timestamp > 0.0) {
        return [NSDate dateWithTimeIntervalSince1970:self.timestamp];
    } else {
        return nil;
    }
}

- (void)setDate:(NSDate *)date
{
    if (date) {
        self.timestamp = [date timeIntervalSince1970];
    } else {
        self.timestamp = 0.0;
    }
}

#pragma mark - Database Access

// Finds a transaction in the database for a given hash. Returns nil if not found.
+ (instancetype) loadTransactionForAccount:(uint32_t)accountIndex hash:(NSData*)txhash database:(FMDatabase*)db
{
    return [[self loadWithCondition:@"accountIndex = ? AND transactionHash = ?"
                             params:@[@(accountIndex), txhash ?: @"n/a" ]
                       fromDatabase:db] firstObject];
}


#pragma mark - MYCDatabaseRecord

/*
 [database registerMigration:@"Create MYCTransactions" withBlock:^BOOL(FMDatabase *db, NSError *__autoreleasing *outError) {
 return [db executeUpdate:
 @"CREATE TABLE MYCTransactions("
 "transactionHash   TEXT NOT NULL," // note: we allow duplicate txs if they happen to pay from one account to another.
 "data              TEXT NOT NULL," // raw transaction in binary
 "blockHeight       INT  NOT NULL," // equals -1 if not confirmed yet.
 "timestamp         INT  NOT NULL," // timestamp.
 "accountIndex      INT  NOT NULL," // index of an account to which this tx belongs.
 "PRIMARY KEY (transactionHash, accountIndex)"  // note: we allow duplicate txs if they happen to pay from one account to another.
 ")"]  &&
 [db executeUpdate:@"CREATE INDEX MYCTransactions_accountIndex ON MYCTransactions (transactionHash)"];
 }];
 */

+ (NSString *)tableName
{
    return @"MYCTransactions";
}

+ (NSArray *)columnNames
{
    return @[MYCDatabaseColumn(transactionHash),
             MYCDatabaseColumn(data),
             MYCDatabaseColumn(blockHeight),
             MYCDatabaseColumn(timestamp),
             MYCDatabaseColumn(accountIndex),
             ];
}

@end
