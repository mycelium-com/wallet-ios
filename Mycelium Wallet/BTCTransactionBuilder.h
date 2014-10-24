#import <Foundation/Foundation.h>

extern NSString* const BTCTransactionBuilderErrorDomain;

typedef NS_ENUM(NSUInteger, BTCTransactionBuilderError) {

    // Change address is not specified.
    BTCTransactionBuilderErrorChangeAddressMissing = 1,

    // No unspent outputs were provided or found.
    BTCTransactionBuilderErrorUnspentOutputsMissing = 2,

    // Unspent outputs are not sufficient to build the transaction.
    BTCTransactionBuilderErrorInsufficientFunds = 3,
};

@class BTCTransaction;
@class BTCTransactionInput;
@class BTCTransactionOutput;
@class BTCTransactionBuilder;
@class BTCTransactionBuilderResult;

@protocol BTCTransactionBuilderDataSource <NSObject>

@required

// Called when needs inputs to spend in a transaction.
// BTCTransactionOutput instances must contain sensible `transactionHash` and `index` properties.
// Reference of BTCTransactionOutput is assigned to BTCTransactionInput so you could access it to sign the inputs.
- (NSEnumerator* /* [BTCTransactionOutput] */) unspentOutputsForTransactionBuilder:(BTCTransactionBuilder*)txbuilder;

@optional

// Called when attempts to sign the inputs. Return nil if key is not available.
- (BTCKey*) transactionBuilder:(BTCTransactionBuilder*)txbuilder keyForInput:(BTCTransactionInput*)txin;

@end

// Transaction builder allows you to compose a transaction with necessary parameters.
// It takes care of picking necessary unspent outputs and singing inputs.
@interface BTCTransactionBuilder : NSObject

// Data source that provides inputs.
// If you do not provide a dataSource, you should provide unspentOutputsEnumerator.
@property(weak,nonatomic) id<BTCTransactionBuilderDataSource> dataSource;

// Instead of using data source, provide unspent outputs directly.
@property(nonatomic) NSEnumerator* unspentOutputsEnumerator;

// Optional list of outputs for which the transaction is intended.
// If outputs is nil or empty array, will attempt to spend all input to change address ("sweeping").
// If not empty, will use the least amount of inputs to cover output values and the fee.
@property(nonatomic) NSArray* outputs;

// Change address where remaining funds should be sent.
// Must not be nil.
@property(nonatomic) BTCAddress* changeAddress;


// Optional configuration properties
// ---------------------------------

// Fee per 1000 bytes. Default is BTCTransactionDefaultFeeRate.
@property(nonatomic) BTCSatoshi feeRate;

// Minimum amount of change below which transaction is not composed.
// If change amount is non-zero and below this value, more unspent outputs are used.
// If change amount is zero, change output is not even created and this property is not used.
// Default value equals feeRate.
@property(nonatomic) BTCSatoshi minimumChange;


// Amount of change that can be forgone as a mining fee if there are no more
// unspent outputs available. If equals zero, no amount is allowed to be forgone.
// Default value equals minimumChange.
// This means builder will never fail with BTCTransactionBuilderErrorInsufficientFunds just because it could not
// find enough unspents for big enough change. In worst case (not enough unspent to bump change) it will forgo the change
// as a part of the mining fee. Set to 0 to avoid forgoing a single satoshi.
@property(nonatomic) BTCSatoshi dustChange;

// Attempts to build and possibly sign a transaction.
// Returns a result object containing the transaction itself
// and metadata about it (fee, input and output balances, indexes of unsigned inputs).
// If failed to build a transaction, returns nil and sets error to one from BTCTransactionBuilderErrorDomain.
- (BTCTransactionBuilderResult*) buildTransaction:(NSError**)errorOut;

@end


// Result of building a transaction. Contains a transaction itself with various metadata.
@interface BTCTransactionBuilderResult : NSObject

// Actual transaction with complete inputs and outputs.
// If some inputs are not signed, unsignedInputsIndexes will contain their indexes.
@property(nonatomic, readonly) BTCTransaction* transaction;

// Indexes of unsigned inputs. Such inputs have BTCTransactionOutput script in place of signatureScript.
// Also, every input has a reference to unspent BTCTransactionOutput provided by data source (or unspentOutputsEnumerator).
@property(nonatomic, readonly) NSIndexSet* unsignedInputsIndexes;

// Complete fee this transaction pays to miners.
// Equals (inputsAmount - outputsAmount).
@property(nonatomic, readonly) BTCSatoshi fee;

// Complete amount on the inputs.
@property(nonatomic, readonly) BTCSatoshi inputsAmount;

// Complete amount on the outputs.
@property(nonatomic, readonly) BTCSatoshi outputsAmount;

@end

