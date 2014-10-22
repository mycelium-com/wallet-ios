//
//  MYCBaseTxOutput.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCDatabaseRecord.h"

@interface MYCBaseTxOutput : MYCDatabaseRecord

@property(nonatomic) NSData* outpointHash;
@property(nonatomic) NSInteger outpointIndex;
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

@end
