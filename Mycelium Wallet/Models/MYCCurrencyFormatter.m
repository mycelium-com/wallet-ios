//
//  MYCCurrencyFormatter.m
//  Mycelium Wallet
//
//  Created by Pascal Edmond on 09/03/2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//

#import "MYCCurrencyFormatter.h"

@interface MYCCurrencyFormatter ()
@property(nonatomic, readwrite) BTCCurrencyConverter* currencyConverter;
@property(nonatomic, readwrite) BTCNumberFormatter* btcFormatter;
@property(nonatomic, readwrite) NSNumberFormatter* fiatFormatter;
@property(nonatomic) BTCNumberFormatter* nakedBtcFormatter;
@property(nonatomic) NSNumberFormatter* nakedFiatFormatter;
@end

@interface MYCMyMultiplierNSNumberFormatter : NSNumberFormatter
@property(nonatomic) NSDecimalNumber* myMultiplier;
@end

@implementation MYCMyMultiplierNSNumberFormatter

- (NSString*) stringFromNumber:(NSNumber *)number {
    if (!_myMultiplier || _myMultiplier.doubleValue == 0) return [super stringFromNumber:number];
    return [super stringFromNumber:[[self decForNum:number] decimalNumberByMultiplyingBy:_myMultiplier]];
}

- (NSNumber*) numberFromString:(NSString *)string {
    if (!_myMultiplier || _myMultiplier.doubleValue == 0) return [super numberFromString:string];
    NSDecimalNumber* num = [self decForNum:[super numberFromString:string]];
    return [num decimalNumberByDividingBy:_myMultiplier];
}

- (NSDecimalNumber*) decForNum:(NSNumber*)num {
    if (![num isKindOfClass:[NSDecimalNumber class]]) {
        return [NSDecimalNumber decimalNumberWithDecimal:num.decimalValue];
    }
    return (NSDecimalNumber*)num;
}

@end

@implementation MYCCurrencyFormatter

// These fix the warning: "Auto property synthesis will not synthesize property 'currencyCode'; it will be implemented by its superclass, use @dynamic to acknowledge intention".
@dynamic currencyCode;
@dynamic currencySymbol;

// Returns a formatter that shows one of BTC units (BTC, mBTC, bits, satoshis).
// Does not perform currency conversion.
- (id) initWithBTCFormatter:(BTCNumberFormatter*)btcFormatter {
    NSParameterAssert(btcFormatter);
    if (self = [super init]) {
        self.btcFormatter = btcFormatter;
        self.nakedBtcFormatter = [[BTCNumberFormatter alloc] initWithBitcoinUnit:self.btcFormatter.bitcoinUnit symbolStyle:BTCNumberFormatterSymbolStyleNone];
    }
    return self;
}

// Returns a formatter that shows the fiat unit (BTC, mBTC, bits, satoshis).
// Does perform currency conversion fiat<->btc.
- (id) initWithCurrencyConverter:(BTCCurrencyConverter*)currencyConverter {
    NSParameterAssert(currencyConverter);
    if (self = [super init]) {
        self.currencyConverter = currencyConverter;
        self.fiatFormatter = [self makeFiatFormatter];
    }
    return self;
}

- (id) initWithDictionary:(NSDictionary*)dict {
    if (dict[@"btcFormatter"]) {
        NSDictionary* btc = dict[@"btcFormatter"];
        return [self initWithBTCFormatter:[[BTCNumberFormatter alloc] initWithBitcoinUnit:[btc[@"bitcoinUnit"] integerValue] symbolStyle:[btc[@"symbolStyle"] integerValue]]];
    }
    if (dict[@"currencyConverter"]) {
        NSDictionary* conv = dict[@"currencyConverter"];
        return [self initWithCurrencyConverter:[[BTCCurrencyConverter alloc] initWithDictionary:conv]];
    }
    return nil;
}

- (NSDictionary*) dictionary {
    if (self.isBitcoinFormatter) {
        return @{@"btcFormatter": @{
                         @"bitcoinUnit": @(self.btcFormatter.bitcoinUnit),
                         @"symbolStyle": @(self.btcFormatter.symbolStyle),
                         }};
    }
    return @{@"currencyConverter": self.currencyConverter.dictionary ?: @{}};
}

- (MYCMyMultiplierNSNumberFormatter*) makeFiatFormatter {
    // For now we only support USD, but will have to support various currency exchanges later.
    MYCMyMultiplierNSNumberFormatter* fmt = [[MYCMyMultiplierNSNumberFormatter alloc] init];
    fmt.lenient = YES;
    fmt.numberStyle = NSNumberFormatterCurrencyStyle;
    fmt.currencyCode = self.currencyConverter.currencyCode;
    fmt.groupingSize = 3;

    // [[NSLocale currentLocale] displayNameForKey:NSLocaleCurrencySymbol value:@"USD"];
    // Returns "$US" for symbol and "dollar des etats unis" for code.
    MYCCurrencyFormatterStyle style = MYCCurrencyFormatterStyleCode; // TODO: add API for that.

    if (style == MYCCurrencyFormatterStyleSymbol){

        fmt.currencySymbol = [self codeToSymbolMapping][fmt.currencyCode];
        fmt.internationalCurrencySymbol = fmt.currencySymbol;
        fmt.minusSign = @"–";
    //#warning TODO: review choice of currency symbol position. If we leave it to locale, then minus sign might look strange.
    //    fmt.positivePrefix = @"";
    //    fmt.positiveSuffix = [@"\xE2\x80\xAF" stringByAppendingString:fmt.currencySymbol];
    //    fmt.negativeFormat = [fmt.positiveFormat stringByReplacingCharactersInRange:[fmt.positiveFormat rangeOfString:@"#"] withString:@"-#"];
    } else if (style == MYCCurrencyFormatterStyleCode) {
        fmt.currencySymbol = fmt.currencyCode;
        fmt.internationalCurrencySymbol = fmt.currencySymbol;
        fmt.minusSign = @"–";
        fmt.positivePrefix = @"";
        fmt.positiveSuffix = [@" " stringByAppendingString:fmt.currencySymbol];
        fmt.negativeFormat = [fmt.positiveFormat stringByReplacingCharactersInRange:[fmt.positiveFormat rangeOfString:@"#"] withString:@"-#"];
    }
    return fmt;
}

- (NSString*) currencyCode {
    if (self.btcFormatter) {
        return self.btcFormatter.unitCode;
    }
    return self.fiatFormatter.currencyCode;
}

- (NSString*) currencySymbol {
    if (self.btcFormatter) {
        return self.btcFormatter.currencySymbol;
    }
    return self.fiatFormatter.currencySymbol;
}

// Complete name of this formatter including market/index name if needed.
// E.g. "BTC", "USD (Coindesk)", "EUR (Paymium)".
- (NSString*) name {
    if (self.btcFormatter) {
        return self.btcFormatter.unitCode;
    }
    return [NSString stringWithFormat:@"%@ (%@)", self.fiatFormatter.currencyCode, self.currencyConverter.sourceName];
}

- (NSNumberFormatter*) nakedFormatter {
    return self.nakedBtcFormatter ?: self.nakedFiatFormatter;
}

- (NSNumberFormatter*) nakedFiatFormatter {
    MYCMyMultiplierNSNumberFormatter* fmt = [self makeFiatFormatter];
    fmt.currencySymbol = @"";
    fmt.internationalCurrencySymbol = @"";
    fmt.positivePrefix = @"";
    fmt.positiveSuffix = @"";
    fmt.minimumFractionDigits = 0;
    fmt.minusSign = @"–";
//    fmt.negativeFormat = [self.fiatFormatter.positiveFormat stringByReplacingCharactersInRange:[self.fiatFormatter.positiveFormat rangeOfString:@"#"] withString:@"-#"];

    // multiplier = exchange rate / 100_000_000.
    fmt.myMultiplier = [self.currencyConverter.averageRate decimalNumberByMultiplyingByPowerOf10:-8];
    return fmt;
}

// Does not perform any conversion, but simply re-formats the input.
- (NSNumberFormatter*) fiatReformatter {
    return self.fiatFormatter;
}

- (BOOL) isBitcoinFormatter {
    return !!self.btcFormatter;
}

- (BOOL) isFiatFormatter {
    return !!self.currencyConverter;
}

- (NSString*) placeholderText {
    if (self.btcFormatter) {
        return [self.btcFormatter placeholderText];
    }
    NSString* decimalPoint = self.fiatFormatter.currencyDecimalSeparator ?: @".";
    return [NSString stringWithFormat:@"0%@00", decimalPoint];
}

- (NSString*) stringFromNumber:(NSNumber *)number {
    if (self.btcFormatter) {
        return [self.btcFormatter stringFromAmount:BTCAmountFromDecimalNumber(number)];
    }
    return [self.fiatFormatter stringFromNumber:[self.currencyConverter fiatFromBitcoin:BTCAmountFromDecimalNumber(number)]];
}

- (NSNumber*) numberFromString:(NSString *)string {
    if (self.btcFormatter) {
        return @([self.btcFormatter amountFromString:string]);
    }
    NSDecimal dec = [[self.fiatFormatter numberFromString:string] decimalValue];
    return @([self.currencyConverter bitcoinFromFiat:[NSDecimalNumber decimalNumberWithDecimal:dec]]);
}


- (NSString *) stringFromAmount:(BTCAmount)amount {
    return [self stringFromNumber:@(amount)];
}

- (BTCAmount) amountFromString:(NSString*)string {
    return BTCAmountFromDecimalNumber([self numberFromString:string]);
}

- (NSDictionary*) codeToSymbolMapping {
    return @{
        @"ALL": @"Lek"
      , @"AFN": @"؋"
      , @"ARS": @"$"
      , @"AWG": @"ƒ"
      , @"AUD": @"$"
      , @"AZN": @"ман"
      , @"BSD": @"$"
      , @"BBD": @"$"
      , @"BYR": @"p."
      , @"BZD": @"BZ$"
      , @"BMD": @"$"
      , @"BOB": @"$b"
      , @"BAM": @"KM"
      , @"BWP": @"P"
      , @"BGN": @"лв"
      , @"BRL": @"R$"
      , @"BND": @"$"
      , @"KHR": @"៛"
      , @"CAD": @"$"
      , @"KYD": @"$"
      , @"CLP": @"$"
      , @"CNY": @"¥"
      , @"COP": @"$"
      , @"CRC": @"₡"
      , @"HRK": @"kn"
      , @"CUP": @"₱"
      , @"CZK": @"Kč"
      , @"DKK": @"kr"
      , @"DOP": @"RD$"
      , @"XCD": @"$"
      , @"EGP": @"£"
      , @"SVC": @"$"
      , @"EEK": @"kr"
      , @"EUR": @"€"
      , @"FKP": @"£"
      , @"FJD": @"$"
      , @"GHC": @"¢"
      , @"GIP": @"£"
      , @"GTQ": @"Q"
      , @"GGP": @"£"
      , @"GYD": @"$"
      , @"HNL": @"L"
      , @"HKD": @"$"
      , @"HUF": @"Ft"
      , @"ISK": @"kr"
      , @"INR": @"₹"
      , @"IDR": @"Rp"
      , @"IRR": @"﷼"
      , @"IMP": @"£"
      , @"ILS": @"₪"
      , @"JMD": @"J$"
      , @"JPY": @"¥"
      , @"JEP": @"£"
      , @"KES": @"KSh"
      , @"KZT": @"лв"
      , @"KPW": @"₩"
      , @"KRW": @"₩"
      , @"KGS": @"лв"
      , @"LAK": @"₭"
      , @"LVL": @"Ls"
      , @"LBP": @"£"
      , @"LRD": @"$"
      , @"LTL": @"Lt"
      , @"MKD": @"ден"
      , @"MYR": @"RM"
      , @"MUR": @"₨"
      , @"MXN": @"$"
      , @"MNT": @"₮"
      , @"MZN": @"MT"
      , @"NAD": @"$"
      , @"NPR": @"₨"
      , @"ANG": @"ƒ"
      , @"NZD": @"$"
      , @"NIO": @"C$"
      , @"NGN": @"₦"
      , @"KPW": @"₩"
      , @"NOK": @"kr"
      , @"OMR": @"﷼"
      , @"PKR": @"₨"
      , @"PAB": @"B/."
      , @"PYG": @"Gs"
      , @"PEN": @"S/."
      , @"PHP": @"₱"
      , @"PLN": @"zł"
      , @"QAR": @"﷼"
      , @"RON": @"lei"
      , @"RUB": @"₽"
      , @"SHP": @"£"
      , @"SAR": @"﷼"
      , @"RSD": @"Дин."
      , @"SCR": @"₨"
      , @"SGD": @"$"
      , @"SBD": @"$"
      , @"SOS": @"S"
      , @"ZAR": @"R"
      , @"KRW": @"₩"
      , @"LKR": @"₨"
      , @"SEK": @"kr"
      , @"CHF": @"Fr."
      , @"SRD": @"$"
      , @"SYP": @"£"
      , @"TZS": @"TSh"
      , @"TWD": @"NT$"
      , @"THB": @"฿"
      , @"TTD": @"TT$"
      , @"TRY": @"₺"
      , @"TRL": @"₤"
      , @"TVD": @"$"
      , @"UGX": @"USh"
      , @"UAH": @"₴"
      , @"GBP": @"£"
      , @"USD": @"$"
      , @"UYU": @"$U"
      , @"UZS": @"лв"
      , @"VEF": @"Bs"
      , @"VND": @"₫"
      , @"YER": @"﷼"
      , @"ZWD": @"Z$"
      };
}

- (id)copyWithZone:(NSZone *)zone {
    NSDictionary* selfDict = [self dictionary];
    return [[MYCCurrencyFormatter alloc] initWithDictionary:selfDict];
}

@end
