//
//  MYCTransaction.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 20.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>
#import "MYCDatabaseRecord.h"

@interface MYCTransaction : MYCDatabaseRecord

@property(nonatomic) NSData* transactionHash;
@property(nonatomic) NSData* data;           // raw transaction in binary
@property(nonatomic) NSInteger blockHeight;  // equals -1 if not confirmed yet.
@property(nonatomic) NSDate* date;           // block timestamp or time when tx was observed first.
@property(nonatomic) NSInteger accountIndex; // index of an account to which this tx belongs.

// Derived property.
@property(nonatomic) BTCTransaction* transaction;

// Finds a transaction in the database for a given hash. Returns nil if not found.
+ (instancetype) loadTransactionForAccount:(NSInteger)accountIndex hash:(NSData*)txhash database:(FMDatabase*)db;

@end
