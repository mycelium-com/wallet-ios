//
//  MYCWalletBackup.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 21.04.2015.
//  Copyright (c) 2015 Mycelium. All rights reserved.
//
// Example:
//
// {
//   "version": "1",
//   "network": "main" or "test",
//   "accounts": [
//     {"type": "bip44",  "label": "label for bip44 account 0",  "path": "44'/0'/0'"},
//     {"type": "bip44",  "label": "label for bip44 account 1",  "path": "44'/0'/1'"},
//     {"type": "bip44",  "label": "label for bip44 account 17", "path": "44'/0'/17'"},
//     {"type": "single", "label": "Vanity Address", "wif": "5KQntKuh..."},
//     {"type": "single", "label": "Watch-Only",     "address": "1CBtcGiv..."},
//     {"type": "trezor", "label": "My Trezor",      "xpub": "xpub6FHa3pjLCk8..."},
//   ],
//   "transactions": {
//     /* txid is reversed transaction hash in hex, see BTCTransactionIDFromHash */
//     /* transactions without any data do not need to be included at all*/
//     "txid1":  {
//         "memo": "Hotel in Lisbon",
//         "recipient": "Expedia, Inc.",
//         "payment_request": "1200849c11778f127d66...",
//         "payment_ack": "478e8a0e260976a30b26...",
//         "fiat_amount": "-265.10",
//         "fiat_code": "EUR",
//         /* unknown keys must be preserved */
//     },
//   },
//   "currency": {
//     "fiat_code": "USD", "EUR" etc,
//     "fiat_source": "Coinbase",
//     "btc_unit": "BTC" | "mBTC" | "uBTC" | "satoshi",
//     /* unknown keys must be preserved */
//   }
//   /* unknown keys must be preserved */
// }

#import "MYCWalletBackup.h"
#import "MYCWallet.h"
#import "MYCCurrencyFormatter.h"
#import <CoreBitcoin/CoreBitcoin.h>
#import <zlib.h>

typedef NS_ENUM(uint8_t, MYCWalletBackupPayloadFormat) {
    MYCWalletBackupPayloadFormatJSON = 0x00,
    MYCWalletBackupPayloadFormatCompressedJSON   = 0x01,
};

@interface MYCWalletBackup ()
@property(nonatomic) NSMutableDictionary* payloadDictionary;
@end

@implementation MYCWalletBackup

@synthesize network=_network;
@synthesize currencyFormatter=_currencyFormatter;

// Decodes backup from binary data (prefixed with a single-byte format version).
- (nullable id) initWithData:(nonnull NSData*)data backupKey:(nonnull NSData*)backupKey {

    if (!data) [NSException raise:@"MYCWalletBackup: Data must not be nil." format:@""];
    if (!backupKey) [NSException raise:@"MYCWalletBackup: Backup key must not be nil." format:@""];

    BTCEncryptedBackup* bak = [BTCEncryptedBackup decrypt:data backupKey:backupKey];
    NSData* payload = bak.decryptedData;

    if (!payload) {
        MYCError(@"MYCWalletBackup: failed to decrypt backup payload (%@ bytes).", @(data.length));
        return nil;
    }

    if (self = [super init]) {
        NSMutableDictionary* dict = [self parsePayloadData:payload];
        if (!dict) {
            return nil;
        }
        _payloadDictionary = dict;
        _version = [dict[@"version"] integerValue] ?: MYCWalletBackupVersion1;
        _date = bak.date;

        if (!dict[@"network"] ||
            [dict[@"network"] isEqualToString:@"main"]) {
            _network = [BTCNetwork mainnet];
        } else if ([dict[@"network"] isEqualToString:@"test"]) {
            _network = [BTCNetwork testnet];
        } else {
            MYCError(@"MYCWalletBackup: unsupported network received: %@", dict[@"network"]);
            return nil;
        }
    }

    return self;
}

// Instantiates a new instance.
- (nonnull id) init {
    if (self = [super init]) {
        _payloadDictionary = [NSMutableDictionary dictionary];
        self.version = MYCWalletBackupVersion1;
    }
    return self;
}

// Encodes and encrypts the backup with a given backup key.
- (nonnull NSData*) dataWithBackupKey:(nonnull NSData*)backupKey {

    if (!backupKey) [NSException raise:@"MYCWalletBackup: Backup key must not be nil." format:@""];

    NSData* payload = [self payloadData];
    BTCEncryptedBackup* bak = [BTCEncryptedBackup encrypt:payload backupKey:backupKey timestamp:[(self.date ?: [NSDate date]) timeIntervalSince1970]];
    if (!bak) {
        MYCError(@"MYCWalletBackup: failed to encrypt payload %@ bytes with backup key (%@ bytes)", @(payload.length), @(backupKey.length));
    }
    return bak.encryptedData;
}

- (BTCNetwork*) network {
    if (!_network) return [BTCNetwork mainnet];
    return _network;
}

- (void) setNetwork:(BTCNetwork * __nonnull)network {
    _network = network ?: [BTCNetwork mainnet];
}

- (void) setCurrencyFormatter:(MYCCurrencyFormatter*)fmt {
    _currencyFormatter = fmt;
    _payloadDictionary[@"currency"] = _payloadDictionary[@"currency"] ?: [NSMutableDictionary dictionary];
    if (fmt.isBitcoinFormatter) {
        [_payloadDictionary[@"currency"] removeObjectForKey:@"fiat_code"];
        [_payloadDictionary[@"currency"] removeObjectForKey:@"fiat_source"];
        _payloadDictionary[@"currency"][@"btc_unit"] = fmt.btcFormatter.unitCode;
    } else {
        [_payloadDictionary[@"currency"] removeObjectForKey:@"btc_unit"];
        _payloadDictionary[@"currency"][@"fiat_code"] = fmt.currencyCode;
        _payloadDictionary[@"currency"][@"fiat_source"] = fmt.currencyConverter.sourceName;
    }
}

- (MYCCurrencyFormatter*) currencyFormatter {
    if (!_currencyFormatter) {
        NSString* code = _payloadDictionary[@"currency"][@"btc_unit"] ?: _payloadDictionary[@"currency"][@"fiat_code"];
        _currencyFormatter = [[MYCWallet currentWallet] currencyFormatterForCode:code];
    }
    return _currencyFormatter;
}

- (nonnull NSDictionary*) dictionary {
    return [self.payloadDictionary copy];
}

- (NSMutableDictionary*) payloadDictionary {

    if (!_payloadDictionary) _payloadDictionary = [NSMutableDictionary dictionary];

    return _payloadDictionary;
}

- (NSData*) payloadData {

    NSMutableDictionary* dict = [self payloadDictionary];

#warning TODO: Fill in missing keys
    _payloadDictionary[@"version"] = @(self.version);
    _payloadDictionary[@"network"] = self.network.paymentProtocolName;

    if (!dict) {
        MYCError(@"nil returned from MYCWalletBackup.payloadDictionary");
        return nil;
    }
    NSError* jsonerror;
    NSData* jsonPayload = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&jsonerror];
    if (!jsonPayload) {
        MYCError(@"MYCWalletBackup: Failed to encode automatic backup: %@", jsonerror);
        return nil;
    }

    NSData* compressedData = [self compressData:jsonPayload];

    NSMutableData* result = [NSMutableData dataWithLength:1 + compressedData.length];
    memcpy((uint8_t*)result.mutableBytes + 1, compressedData.bytes, compressedData.length);
    ((uint8_t*)result.mutableBytes)[0] = MYCWalletBackupPayloadFormatCompressedJSON;
    return result;
}

- (NSMutableDictionary*) parsePayloadData:(NSData*)payloadData {
    // Must have at least 2 bytes: one for prefix, another for data.
    if (payloadData.length <= 1) return nil;

    MYCWalletBackupPayloadFormat fmt = ((uint8_t*)payloadData.bytes)[0];

    NSData* json = nil;
    if (fmt == MYCWalletBackupPayloadFormatJSON) {

        json = [payloadData subdataWithRange:NSMakeRange(1, payloadData.length - 1)];

    } else if (fmt == MYCWalletBackupPayloadFormatCompressedJSON) {

        // Try to uncompress first
        json = [self uncompressData:[payloadData subdataWithRange:NSMakeRange(1, payloadData.length - 1)]];
        if (!json) {
            MYCError(@"MYCWalletBackup: cannot uncompress zipped JSON payload.");
            return nil;
        }

    } else {
        MYCError(@"MYCWalletBackup: unsupported payload prefix: %@", @(fmt));
        return nil;
    }

    NSError* parseError = nil;
    NSMutableDictionary* dict = [NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:&parseError];
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        MYCError(@"MYCWalletBackup: cannot decode JSON payload: %@", parseError);
        return nil;
    }

    return dict;
}

- (NSData*) compressData:(NSData*)inputData {

    if (inputData.length < 1) return nil;

    const NSUInteger ChunkSize = 16384;

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.avail_in = (uint)[inputData length];
    stream.next_in = (Bytef *)[inputData bytes];
    stream.total_out = 0;
    stream.avail_out = 0;

    //int compression = (int)(roundf(level * 9));
    int compression = Z_DEFAULT_COMPRESSION;
    if (deflateInit2(&stream, compression, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK) {
        NSMutableData *data = [NSMutableData dataWithLength:ChunkSize];
        while (stream.avail_out == 0) {
            if (stream.total_out >= [data length]) {
                data.length += ChunkSize;
            }
            stream.next_out = (uint8_t *)[data mutableBytes] + stream.total_out;
            stream.avail_out = (uInt)([data length] - stream.total_out);
            deflate(&stream, Z_FINISH);
        }
        deflateEnd(&stream);
        data.length = stream.total_out;
        return data;
    }
    return nil;
}

- (NSData*) uncompressData:(NSData*)inputData {

    if (inputData.length < 1) return nil;

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.avail_in = (uint)[inputData length];
    stream.next_in = (Bytef *)[inputData bytes];
    stream.total_out = 0;
    stream.avail_out = 0;

    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)([inputData length] * 1.5)];
    if (inflateInit2(&stream, 47) == Z_OK) {
        int status = Z_OK;
        while (status == Z_OK) {
            if (stream.total_out >= [data length]) {
                data.length += [inputData length] / 2;
            }
            stream.next_out = (uint8_t *)[data mutableBytes] + stream.total_out;
            stream.avail_out = (uInt)([data length] - stream.total_out);
            status = inflate (&stream, Z_SYNC_FLUSH);
        }
        if (inflateEnd(&stream) == Z_OK) {
            if (status == Z_STREAM_END) {
                data.length = stream.total_out;
                return data;
            }
        }
    }
    return nil;
}

@end
