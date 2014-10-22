#import "BTCBitcoinURL.h"

@implementation BTCBitcoinURL

+ (NSURL*) URLWithAddress:(BTCAddress*)address amount:(BTCSatoshi)amount label:(NSString*)label
{
    if (!address || amount <= 0) return nil;

    NSString* amountString = [NSString stringWithFormat:@"%d.%08d", (int)(amount / BTCCoin), (int)(amount % BTCCoin)];

    NSMutableString* s = [NSMutableString stringWithFormat:@"bitcoin:%@?amount=%@", address.base58String, amountString];

    if (label && label.length > 0)
    {
        [s appendFormat:@"&label=%@", [label stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }

    return [NSURL URLWithString:s];
}

@end
