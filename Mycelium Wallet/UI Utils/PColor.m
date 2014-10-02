#import "PColor.h"

@implementation PColor

+ (id) colorWithColorRef:(CGColorRef)color
{
	PColor* res = [[PColor alloc] init];
	res.CGColor = color;
	return res;
}

- (CGColorRef) CGColor
{
	return _CGColorRef;
}

- (void)setCGColor:(CGColorRef)newColor
{
	if (newColor != _CGColorRef)
	{
		CGColorRelease(_CGColorRef);
		_CGColorRef = newColor;
		CGColorRetain(_CGColorRef);
	}
}

- (void)dealloc
{
	CGColorRelease(_CGColorRef);
	_CGColorRef = nil;
}

#if TARGET_OS_IPHONE
+ (PColorRGB) componentsFromColor:(UIColor*)color
#else
+ (PColorRGB) componentsFromColor:(NSColor*)color
#endif
{
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char resultingPixel[4];
    CGContextRef context = CGBitmapContextCreate(&resultingPixel,
                                                 1,
                                                 1,
                                                 8,
                                                 4,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);

    PColorRGB rgb;
    rgb.r = resultingPixel[0] / 255.0f;
    rgb.g = resultingPixel[1] / 255.0f;
    rgb.b = resultingPixel[2] / 255.0f;

    return rgb;
}



// Returns perceived brightness for a given color according to HSP model
// http://alienryderflex.com/hsp.html
#if TARGET_OS_IPHONE
+ (float) perceivedBrightness:(UIColor*)color
#else
+ (float) perceivedBrightness:(NSColor*)color
#endif
{
    PColorRGB rgb = [self componentsFromColor:color];
    return sqrtf(0.299*(rgb.r*rgb.r) + 0.587*(rgb.g*rgb.g) + 0.114*(rgb.b*rgb.b));
}

// Returns the same color with adjusted brightness.
// Sufficiently big factor yields white color.
// Zero factor yields black color.
// 2.0 makes color 2x brighter.
// 0.5 makes color 2x darker.
#if TARGET_OS_IPHONE
+ (UIColor*) color:(UIColor*)color withAdjustedBrightness:(float)factor
#else
+ (NSColor*) color:(NSColor*)color withAdjustedBrightness:(float)factor
#endif
{
    PColorRGB rgb = [self componentsFromColor:color];

    rgb.r = MIN(1.0, rgb.r * factor);
    rgb.g = MIN(1.0, rgb.g * factor);
    rgb.b = MIN(1.0, rgb.b * factor);

#if TARGET_OS_IPHONE
    return [UIColor colorWithRed:rgb.r green:rgb.g blue:rgb.b alpha:1.0];
#else
    return [NSColor colorWithCalibratedRed:rgb.r green:rgb.g blue:rgb.b alpha:1.0];
#endif
}

#if TARGET_OS_IPHONE
+ (UIColor*) linearMix:(float)factor color1:(UIColor*)color1 color2:(UIColor*)color2
#else
+ (NSColor*) linearMix:(float)factor color1:(NSColor*)color1 color2:(NSColor*)color2
#endif
{
    PColorRGB rgb1 = [self componentsFromColor:color1];
    PColorRGB rgb2 = [self componentsFromColor:color2];

    PColorRGB rgb;
    rgb.r = MAX(0.0, MIN(1.0, rgb1.r * (1.0 - factor) + rgb2.r * factor));
    rgb.g = MAX(0.0, MIN(1.0, rgb1.g * (1.0 - factor) + rgb2.g * factor));
    rgb.b = MAX(0.0, MIN(1.0, rgb1.b * (1.0 - factor) + rgb2.b * factor));

#if TARGET_OS_IPHONE
    return [UIColor colorWithRed:rgb.r green:rgb.g blue:rgb.b alpha:1.0];
#else
    return [NSColor colorWithCalibratedRed:rgb.r green:rgb.g blue:rgb.b alpha:1.0];
#endif
}

@end
