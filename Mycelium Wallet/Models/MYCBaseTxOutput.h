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

@property(nonatomic, readonly) BTCScript* script;
@property(nonatomic, readonly) BTCTransactionOutput* transactionOutput;

+ (instancetype) loadOutputForAccount:(uint32_t)accountIndex hash:(NSData*)prevHash index:(uint32_t)prevIndex database:(FMDatabase*)db;

@end
