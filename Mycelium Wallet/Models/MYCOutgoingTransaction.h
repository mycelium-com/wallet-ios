//
//  MYCOutgoingTransaction.h
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 27.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>
#import "MYCDatabaseRecord.h"

@interface MYCOutgoingTransaction : MYCDatabaseRecord

@property(nonatomic) NSData* transactionHash;
@property(nonatomic) NSData* data;           // raw transaction in binary

// Derived property.
@property(nonatomic) BTCTransaction* transaction;
@property(nonatomic) NSString* transactionID;

@end
