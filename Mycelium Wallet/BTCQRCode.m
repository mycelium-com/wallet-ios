//
//  BTCQRCode.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 08.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "BTCQRCode.h"

@implementation BTCQRCode


+ (UIImage*) imageForURL:(NSURL*)url size:(CGSize)size scale:(CGFloat)scale
{
    return [self imageForString:url.absoluteString size:size scale:scale];
}

+ (UIImage*) imageForString:(NSString*)string size:(CGSize)size scale:(CGFloat)scale
{
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];

    [filter setValue:[string dataUsingEncoding:NSISOLatin1StringEncoding] forKey:@"inputMessage"];
    [filter setValue:@"L" forKey:@"inputCorrectionLevel"];

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGImageRef cgimage = [[CIContext contextWithOptions:nil] createCGImage:filter.outputImage
                                                              fromRect:filter.outputImage.extent];

    UIImage* image = nil;
    if (context)
    {
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, CGContextGetClipBoundingBox(context), cgimage);
        image = [UIImage imageWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage
                                                scale:scale
                                          orientation:UIImageOrientationDownMirrored];
    }

    UIGraphicsEndImageContext();
    CGImageRelease(cgimage);

    return image;
}



@end
