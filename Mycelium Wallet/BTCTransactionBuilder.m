#import "BTCTransactionBuilder.h"

NSString* const BTCTransactionBuilderErrorDomain = @"com.oleganza.CoreBitcoin.TransactionBuilder";

@interface BTCTransactionBuilderResult ()
@property(nonatomic, readwrite) BTCTransaction* transaction;
@property(nonatomic, readwrite) NSIndexSet* unsignedInputsIndexes;
@property(nonatomic, readwrite) BTCSatoshi fee;
@property(nonatomic, readwrite) BTCSatoshi inputsAmount;
@property(nonatomic, readwrite) BTCSatoshi outputsAmount;
@end

@implementation BTCTransactionBuilder

- (id) init
{
    if (self = [super init])
    {
        _feeRate = BTCTransactionDefaultFeeRate;
        _minimumChange = -1; // so it picks feeRate at runtime.
        _dustChange = -1; // so it picks minimumChange at runtime.
    }
    return self;
}

- (BTCTransactionBuilderResult*) buildTransaction:(NSError**)errorOut
{
    return nil;
}


// Configuration properties

- (NSEnumerator*) unspentOutputsEnumerator
{
    if (_unspentOutputsEnumerator) return _unspentOutputsEnumerator;

    if (self.dataSource)
    {
        return [self.dataSource unspentOutputsForTransactionBuilder:self];
    }

    return nil;
}

- (BTCSatoshi) minimumChange
{
    if (_minimumChange < 0) return self.feeRate;
    return _minimumChange;
}

- (BTCSatoshi) dustChange
{
    if (_dustChange < 0) return self.minimumChange;
    return _dustChange;
}

@end
