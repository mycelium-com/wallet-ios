//
//  MYCMinerFeeEstimations.m
//  Mycelium Wallet
//
//  Created by Andrew Toth on 2016-03-02.
//  Copyright © 2016 Mycelium. All rights reserved.
//

#import "MYCMinerFeeEstimations.h"

@implementation MYCMinerFeeEstimations

+ (instancetype)estimationsWithDictionary:(NSDictionary *)dict {
    MYCMinerFeeEstimations * estimations = [MYCMinerFeeEstimations new];
    estimations.block1 = [dict[@"1"] intValue];
    estimations.block2 = [dict[@"2"] intValue];
    estimations.block3 = [dict[@"3"] intValue];
    estimations.block4 = [dict[@"4"] intValue];
    estimations.block5 = [dict[@"5"] intValue];
    estimations.block10 = [dict[@"10"] intValue];
    estimations.block15 = [dict[@"15"] intValue];
    estimations.block20 = [dict[@"20"] intValue];
    return estimations;
}

- (BTCAmount)lowPriority {
    return self.block20;
}

- (BTCAmount)economy {
    return self.block10;
}

- (BTCAmount)normal {
    return self.block3;
}

- (BTCAmount)priority {
    return self.block1;
}

@end
