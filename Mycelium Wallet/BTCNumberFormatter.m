#import "BTCNumberFormatter.h"

#define NarrowNbsp @"\xE2\x80\xAF"

NSString* const BTCNumberFormatterBitcoinCode    = @"XBT";

NSString* const BTCNumberFormatterSymbolBTC      = @"Ƀ" @"";
NSString* const BTCNumberFormatterSymbolMilliBTC = @"mɃ";
NSString* const BTCNumberFormatterSymbolBit      = @"ƀ";
NSString* const BTCNumberFormatterSymbolSatoshi  = @"ṡ";


@implementation BTCNumberFormatter

- (id) initWithBitcoinUnit:(BTCNumberFormatterUnit)unit
{
    return [self initWithBitcoinUnit:unit symbolStyle:BTCNumberFormatterSymbolStyleNone];
}

- (id) initWithBitcoinUnit:(BTCNumberFormatterUnit)unit symbolStyle:(BTCNumberFormatterSymbolStyle)symbolStyle
{
    if (self = [super init])
    {
        _bitcoinUnit = unit;
        _symbolStyle = symbolStyle;

        self.numberStyle = NSNumberFormatterCurrencyStyle;
        self.currencyCode = @"XBT";
        self.negativeFormat = [self.positiveFormat stringByReplacingCharactersInRange:[self.positiveFormat rangeOfString:@"#"] withString:@"-#"];

        [self updateFormatterProperties];
    }
    return self;
}

- (void) setBitcoinUnit:(BTCNumberFormatterUnit)bitcoinUnit
{
    if (_bitcoinUnit == bitcoinUnit) return;
    _bitcoinUnit = bitcoinUnit;
    [self updateFormatterProperties];
}

- (void) setSymbolStyle:(BTCNumberFormatterSymbolStyle)suffixStyle
{
    if (_symbolStyle == suffixStyle) return;
    _symbolStyle = suffixStyle;
    [self updateFormatterProperties];
}

- (void) updateFormatterProperties
{
    self.currencySymbol = [NSString stringWithFormat:@"%@%@%@", NarrowNbsp, [self bitcoinSymbol], NarrowNbsp];
    self.internationalCurrencySymbol = self.currencySymbol;

    self.minimumFractionDigits = 0; // On iOS 8 we have to set this *after* setting the currency symbol
    self.maximumFractionDigits = 2;

    self.maximum = @(BTC_MAX_MONEY/(int64_t)pow(10.0, self.maximumFractionDigits));
}

- (NSString*) bitcoinSymbol
{
    return nil;
}

- (NSNumber*) numberFromSatoshis:(BTCSatoshi)satoshis
{
    switch (_bitcoinUnit) {
        case BTCNumberFormatterUnitSatoshi:
            return @(satoshis);
        case BTCNumberFormatterUnitBit:
            return [[NSDecimalNumber alloc] initWithMantissa:ABS(satoshis) exponent:-2 isNegative:satoshis < 0];
        case BTCNumberFormatterUnitMilliBTC:
            return [[NSDecimalNumber alloc] initWithMantissa:ABS(satoshis) exponent:-5 isNegative:satoshis < 0];
        case BTCNumberFormatterUnitBTC:
            return [[NSDecimalNumber alloc] initWithMantissa:ABS(satoshis) exponent:-8 isNegative:satoshis < 0];
        default:
            return nil;
    }
}

- (BTCSatoshi) satoshisFromNumber:(NSNumber*)number
{
    switch (_bitcoinUnit) {
        case BTCNumberFormatterUnitSatoshi:
            return number.longLongValue;
        case BTCNumberFormatterUnitBit:
//            return number.decimalValue
        case BTCNumberFormatterUnitMilliBTC:
//            return [[NSDecimalNumber alloc] initWithMantissa:ABS(satoshis) exponent:-5 isNegative:satoshis < 0];
        case BTCNumberFormatterUnitBTC:
//            return [[NSDecimalNumber alloc] initWithMantissa:ABS(satoshis) exponent:-8 isNegative:satoshis < 0];
        default:
            return 0;
    }
}

- (NSString *) stringFromAmount:(BTCSatoshi)amount
{
    return [self stringFromNumber:[self numberFromSatoshis:amount]];
}

- (BTCSatoshi) amountFromString:(NSString *)string
{
    return [self satoshisFromNumber:[self numberFromString:string]];
}

@end
