//
//  MYCBaseTxOutput.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCDatabaseRecord.h"

@interface MYCBaseTxOutput : MYCDatabaseRecord

@property(nonatomic) NSData* outpointHash; // hash of a tx in which this output is used
@property(nonatomic) NSInteger outpointIndex; // index of this output in its tx
@property(nonatomic) NSInteger blockHeight;
@property(nonatomic) NSData* scriptData;
@property(nonatomic) BTCSatoshi value;
@property(nonatomic) BOOL coinbase;
@property(nonatomic) NSInteger accountIndex; // 0, 1, 2, ...
@property(nonatomic) NSInteger change; // 0 or 1 according to BIP44.
@property(nonatomic) NSInteger keyIndex; // 0, 1, 2, ...

// Derived properties
@property(nonatomic) BTCScript* script;
@property(nonatomic) BTCTransactionOutput* transactionOutput;
@property(nonatomic) BTCOutpoint* outpoint; // derived from outpointHash and outpointIndex

+ (instancetype) loadOutputForAccount:(NSInteger)accountIndex hash:(NSData*)prevHash index:(uint32_t)prevIndex database:(FMDatabase*)db;

+ (NSArray*) loadOutputsForAccount:(NSInteger)accountIndex database:(FMDatabase*)db;

// Returns YES if there is valid change and keyIndex values (not -1) which means this output belongs to its account.
- (BOOL) isMyOutput;

@end
