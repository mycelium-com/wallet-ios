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

@class MYCWalletAccount;
@class MYCTransactionDetails;
@interface MYCTransaction : MYCDatabaseRecord

@property(nonatomic) NSData* transactionHash;
@property(nonatomic) NSData* data;           // raw transaction in binary
@property(nonatomic) NSInteger blockHeight;  // equals -1 if not confirmed yet.
@property(nonatomic) NSDate* date;           // block timestamp or time when tx was observed first.
@property(nonatomic) NSInteger accountIndex; // index of an account to which this tx belongs.

@property(nonatomic) MYCWalletAccount* account;

// Derived property.
@property(nonatomic) BTCTransaction* transaction;
@property(nonatomic) NSString* transactionID;

// Details (see `-loadDetailsFromDatabase:`)
@property(nonatomic) NSString* label; // Label or address.
@property(nonatomic) BTCAmount amountTransferred; // Negative if spent
@property(nonatomic) BTCAmount inputsAmount;
@property(nonatomic) BTCAmount outputsAmount;
@property(nonatomic) BTCAmount fee; // Mining fee spent by this transaction
@property(nonatomic) NSArray* transactionInputs; // BTCTransactionInput instances with userInfo @"value" and @"address"
@property(nonatomic) NSArray* transactionOutputs; // BTCTransactionOutput instances directly from `-transaction`.
@property(nonatomic) MYCTransactionDetails* transactionDetails;

// Loads basic details about transaction from database (label, amountTransferred).
- (BOOL) loadDetailsFromDatabase:(FMDatabase*)db;


// Finds a transaction in the database for a given hash. Returns nil if not found.
+ (instancetype) loadTransactionWithHash:(NSData*)txhash account:(MYCWalletAccount*)account database:(FMDatabase*)db;

// Finds young transactions with a given height or newer (including unconfirmed ones).
+ (NSArray*) loadRecentTransactionsSinceHeight:(NSInteger)height account:(MYCWalletAccount*)account database:(FMDatabase*)db;

// Finds unconfirmed transactions (with height = -1)
+ (NSArray*) loadUnconfirmedTransactionsForAccount:(MYCWalletAccount*)account database:(FMDatabase*)db;

// Loads total number of transactions associated with this account
+ (NSUInteger) countTransactionsForAccount:(MYCWalletAccount*)account database:(FMDatabase*)db;

// Loads a transaction at index
+ (MYCTransaction*) loadTransactionAtIndex:(NSUInteger)txindex account:(MYCWalletAccount*)account database:(FMDatabase*)db;

@end
