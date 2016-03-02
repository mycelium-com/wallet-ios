//
//  MYCMinerFeeEstimations.h
//  Mycelium Wallet
//
//  Created by Andrew Toth on 2016-03-02.
//  Copyright © 2016 Mycelium. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MYCMinerFeeEstimations : NSObject

+ (instancetype)estimationsWithDictionary:(NSDictionary *)dict;

@property(nonatomic) BTCAmount block1;
@property(nonatomic) BTCAmount block2;
@property(nonatomic) BTCAmount block3;
@property(nonatomic) BTCAmount block4;
@property(nonatomic) BTCAmount block5;
@property(nonatomic) BTCAmount block10;
@property(nonatomic) BTCAmount block15;
@property(nonatomic) BTCAmount block20;

@property(nonatomic) BTCAmount lowPriority;
@property(nonatomic) BTCAmount economy;
@property(nonatomic) BTCAmount normal;
@property(nonatomic) BTCAmount priority;

@end
