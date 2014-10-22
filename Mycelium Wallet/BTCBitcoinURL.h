#import <Foundation/Foundation.h>

/*!
 * Class to compose and handle various Bitcoin URLs according to BIP21.
 * See: https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki
 */
@interface BTCBitcoinURL : NSObject

/*!
 * Makes a URL in form "bitcoin:<address>?amount=1.2345&label=<label>.
 * @param address Address to be rendered in base58 format.
 * @param amount  Amount in satoshis. Note that URI scheme dictates to render this amount as a decimal number in BTC.
 * @param label   Optional label.
 */
+ (NSURL*) URLWithAddress:(BTCAddress*)address amount:(BTCSatoshi)amount label:(NSString*)label;

// TODO: support arbitrary keys and values.

// TODO: support handling URL from UIApplicationDelegate.

@end
