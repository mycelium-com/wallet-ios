#import "BTCTransactionBuilder.h"
#import "BTCTransaction.h"
#import "BTCTransactionOutput.h"
#import "BTCTransactionInput.h"
#import "BTCAddress.h"
#import "BTCScript.h"
#import "BTCKey.h"

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
    if (!self.changeScript)
    {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCTransactionBuilderErrorDomain code:BTCTransactionBuilderInsufficientFunds userInfo:nil];
        return nil;
    }

    NSEnumerator* unspentsEnumerator = self.unspentOutputsEnumerator;

    if (!unspentsEnumerator)
    {
        if (errorOut) *errorOut = [NSError errorWithDomain:BTCTransactionBuilderErrorDomain code:BTCTransactionBuilderUnspentOutputsMissing userInfo:nil];
        return nil;
    }

    BTCTransactionBuilderResult* result = [[BTCTransactionBuilderResult alloc] init];
    result.transaction = [[BTCTransaction alloc] init];

    // If no outputs given, try to spend all available unspents.
    if (self.outputs.count == 0)
    {
        result.inputsAmount = 0;

        for (BTCTransactionOutput* utxo in unspentsEnumerator)
        {
            result.inputsAmount += utxo.value;

            BTCTransactionInput* txin = [self makeTransactionInputWithUnspentOutput:utxo];
            [result.transaction addInput:txin];
        }

        if (result.transaction.inputs.count == 0)
        {
            if (errorOut) *errorOut = [NSError errorWithDomain:BTCTransactionBuilderErrorDomain code:BTCTransactionBuilderUnspentOutputsMissing userInfo:nil];
            return nil;
        }

        // Prepare a destination output.
        // Value will be determined after computing the fee.
        BTCTransactionOutput* changeOutput = [[BTCTransactionOutput alloc] initWithValue:BTC_MAX_MONEY script:self.changeScript];
        [result.transaction addOutput:changeOutput];

        result.fee = [self computeFeeForTransaction:result.transaction];
        result.outputsAmount = result.inputsAmount - result.fee;

        // Check if inputs cover the fees
        if (result.outputsAmount < 0)
        {
            if (errorOut) *errorOut = [NSError errorWithDomain:BTCTransactionBuilderErrorDomain code:BTCTransactionBuilderInsufficientFunds userInfo:nil];
            return nil;
        }

        // Set the output value as needed
        changeOutput.value = result.outputsAmount;

        result.unsignedInputsIndexes = [self attemptToSignTransaction:result.transaction error:errorOut];
        if (!result.unsignedInputsIndexes)
        {
            return nil;
        }

        return result;

    } // if no outputs

    // We are having one or more outputs (e.g. normal payment)
    // Need to find appropriate unspents and compose a transaction.

    // Prepare all outputs

    result.outputsAmount = 0; // will contain change value after all inputs are finalized

    for (BTCTransactionOutput* txout in self.outputs)
    {
        result.outputsAmount += txout.value;
        [result.transaction addOutput:txout];
    }

    // We'll determine final change value depending on inputs.
    // Setting default to MAX_MONEY will protect against a bug when we fail to update the amount and
    // spend unexpected amount on mining fees.
    BTCTransactionOutput* changeOutput = [[BTCTransactionOutput alloc] initWithValue:BTC_MAX_MONEY script:self.changeScript];
    [result.transaction addOutput:changeOutput];

    // We have specific outputs with specific amounts, so we need to select the best amount of coins.

    result.inputsAmount = 0;

    for (BTCTransactionOutput* utxo in unspentsEnumerator)
    {
        result.inputsAmount += utxo.value;

        BTCTransactionInput* txin = [self makeTransactionInputWithUnspentOutput:utxo];
        [result.transaction addInput:txin];

        // Before computing the fee, quick check if we have enough inputs to cover the outputs.
        // If not, go and add one more utxo before wasting time computing fees.
        if (result.inputsAmount < result.outputsAmount)
        {
            // Try adding more unspent outputs on the next cycle.
            continue;
        }

        BTCSatoshi fee = [self computeFeeForTransaction:result.transaction];

        BTCSatoshi change = result.inputsAmount - result.outputsAmount - fee;

        if (change >= self.minimumChange)
        {
            // We have a big enough change, set missing values and return.
            changeOutput.value = change;
            result.outputsAmount += change;
            result.fee = fee;

            result.unsignedInputsIndexes = [self attemptToSignTransaction:result.transaction error:errorOut];
            if (!result.unsignedInputsIndexes)
            {
                return nil;
            }
            return result;
        }
        else if (change > self.dustChange && change < self.minimumChange)
        {
            // We have a shitty change: not small enough to forgo, not big enough to be useful.
            // Try adding more utxos on the next cycle (or fail if no more utxos are available).
        }
        else if (change >= 0 && change <= self.dustChange)
        {
            // This also includes the case when change is exactly zero satoshis.
            // Remove the change output, keep existing outputsAmount, set fee and try to sign.

            NSMutableArray* txoutputs = [result.transaction.outputs mutableCopy];
            [txoutputs removeObjectIdenticalTo:changeOutput];
            result.transaction.outputs = txoutputs;
            result.fee = fee;
            result.unsignedInputsIndexes = [self attemptToSignTransaction:result.transaction error:errorOut];
            if (!result.unsignedInputsIndexes)
            {
                return nil;
            }
            return result;
        }
        else
        {
            // Change is negative, we need more funds for this transaction.
            // Try adding more utxos on the next cycle.
        }
    }

    // If we haven't finished within the loop, then we don't have enough unspent outputs and should fail.

    BTCTransactionBuilderError errorCode = BTCTransactionBuilderInsufficientFunds;
    if (result.transaction.inputs.count == 0)
    {
        errorCode = BTCTransactionBuilderUnspentOutputsMissing;
    }
    if (errorOut) *errorOut = [NSError errorWithDomain:BTCTransactionBuilderErrorDomain code:errorCode userInfo:nil];
    return nil;
}




// Helpers



- (BTCTransactionInput*) makeTransactionInputWithUnspentOutput:(BTCTransactionOutput*)utxo
{
    BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];

    if (!utxo.transactionHash || utxo.index == BTCTransactionOutputIndexUnknown)
    {
        [[NSException exceptionWithName:@"Incorrect unspent transaction output" reason:@"Unspent output must have valid -transactionHash and -index properties" userInfo:nil] raise];
    }

    txin.previousHash = utxo.transactionHash;
    txin.previousIndex = utxo.index;
    txin.signatureScript = utxo.script; // put the output script here so the signer knows which key to use.
    txin.transactionOutput = utxo;

    return txin;
}


- (BTCSatoshi) computeFeeForTransaction:(BTCTransaction*)tx
{
    // Compute fees for this tx by composing a tx with properly sized dummy signatures.
    BTCTransaction* simtx = [tx copy];
    for (BTCTransactionInput* txin in simtx.inputs)
    {
        NSAssert(!!txin.transactionOutput, @"must have transactionOutput");
        BTCScript* txoutScript = txin.transactionOutput.script;
        txin.signatureScript = [txoutScript simulatedSignatureScriptWithOptions:BTCScriptSimulationMultisigP2SH];

        // TODO: if cannot match the simulated signature, use data source to provide one. (If signing API available, then use it.)
        if (!txin.signatureScript) txin.signatureScript = txoutScript;
    }
    return [simtx estimatedFeeWithRate:self.feeRate];
}


// Tries to sign a transaction and returns index set of unsigned inputs.
- (NSIndexSet*) attemptToSignTransaction:(BTCTransaction*)tx error:(NSError**)errorOut
{
    // By default, all inputs are marked to be signed.
    NSMutableIndexSet* unsignedIndexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < tx.inputs.count; i++)
    {
        [unsignedIndexes addIndex:i];
    }

    // Check if we can possibly sign anything. Otherwise return early.
    if (tx.inputs.count == 0 || !self.dataSource)
    {
        return unsignedIndexes;
    }

    // Try to sign each input.
    for (uint32_t i = 0; i < tx.inputs.count; i++)
    {
        // We support two kinds of scripts: p2pkh (modern style) and p2pk (old style)
        // For each of these we support compressed and uncompressed pubkeys.
        BTCTransactionInput* txin = tx.inputs[i];
        BTCScript* outputScript = txin.signatureScript;
        BTCKey* key = nil;

        if ([self.dataSource respondsToSelector:@selector(transactionBuilder:keyForUnspentOutput:)])
        {
            key = [self.dataSource transactionBuilder:self keyForUnspentOutput:txin.transactionOutput];
        }

        BOOL didSign = NO;
        if (key)
        {
            NSData* cpk = key.compressedPublicKey;
            NSData* ucpk = key.uncompressedPublicKey;

            BTCSignatureHashType hashtype = SIGHASH_ALL;

            NSData* sighash = [tx signatureHashForScript:[outputScript copy] inputIndex:i hashType:hashtype error:errorOut];
            if (!sighash) return nil;

            // Most common case: P2PKH with compressed pubkey (because of BIP32)
            BTCScript* p2cpkhScript = [[BTCScript alloc] initWithAddress:[BTCPublicKeyAddress addressWithData:BTCHash160(cpk)]];
            if ([outputScript.data isEqual:p2cpkhScript.data])
            {
                txin.signatureScript = [[[BTCScript new] appendData:[key signatureForHash:sighash withHashType:hashtype]] appendData:cpk];
                [unsignedIndexes removeIndex:i];
                didSign = YES;
            }
            else
            {
                // Less common case: P2PKH with uncompressed pubkey (when not using BIP32)
                BTCScript* p2ucpkhScript = [[BTCScript alloc] initWithAddress:[BTCPublicKeyAddress addressWithData:BTCHash160(ucpk)]];
                if ([outputScript.data isEqual:p2ucpkhScript.data])
                {
                    txin.signatureScript = [[[BTCScript new] appendData:[key signatureForHash:sighash withHashType:hashtype]] appendData:ucpk];
                    [unsignedIndexes removeIndex:i];
                    didSign = YES;
                }
                else
                {
                    BTCScript* p2cpkScript = [[[BTCScript new] appendData:cpk] appendOpcode:OP_CHECKSIG];
                    BTCScript* p2ucpkScript = [[[BTCScript new] appendData:ucpk] appendOpcode:OP_CHECKSIG];

                    if ([outputScript.data isEqual:p2cpkScript] ||
                        [outputScript.data isEqual:p2ucpkScript])
                    {
                        txin.signatureScript = [[BTCScript new] appendData:[key signatureForHash:sighash withHashType:hashtype]];
                        [unsignedIndexes removeIndex:i];
                        didSign = YES;
                    }
                    else
                    {
                        // Not supported script type.
                    }
                }
            }
        }

        // Ask to sign the transaction input to sign this if that's some kind of special input or script.
        if (!didSign && [self.dataSource respondsToSelector:@selector(transactionBuilder:signatureScriptForTransaction:script:inputIndex:)])
        {
            BTCScript* sigScript = [self.dataSource transactionBuilder:self signatureScriptForTransaction:tx script:outputScript inputIndex:i];
            if (sigScript)
            {
                txin.signatureScript = sigScript;
                [unsignedIndexes removeIndex:i];
            }
        }

    } // each input

    return nil;
}



// Properties



- (BTCScript*) changeScript
{
    if (_changeScript) return _changeScript;

    if (!self.changeAddress) return nil;

    return [[BTCScript alloc] initWithAddress:self.changeAddress.publicAddress];
}

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


@implementation BTCTransactionBuilderResult
@end

