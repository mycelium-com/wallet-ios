#import <TargetConditionals.h>
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif


typedef struct {
    float r;
    float g;
    float b;
} PColorRGB;

@interface PColor : NSObject
{
	CGColorRef	_CGColorRef;
}
+ (id) colorWithColorRef:(CGColorRef)color;
@property CGColorRef CGColor;

// This method extracts correct RGB components from color in any color space.
// So you can use [UIColor whiteColor] and it will Just Work™.
#if TARGET_OS_IPHONE
+ (PColorRGB) componentsFromColor:(UIColor*)color;
#else
+ (PColorRGB) componentsFromColor:(NSColor*)color;
#endif

// Returns perceived brightness for a given color according to HSP model
// http://alienryderflex.com/hsp.html
#if TARGET_OS_IPHONE
+ (float) perceivedBrightness:(UIColor*)color;
#else
+ (float) perceivedBrightness:(NSColor*)color;
#endif

// Returns the same color with adjusted brightness.
// Very big factor yields white color.
// Zero factor yields black color.
// 2.0 makes color 2x brighter.
// 0.5 makes color 2x darker.
#if TARGET_OS_IPHONE
+ (UIColor*) color:(UIColor*)color withAdjustedBrightness:(float)factor;
#else
+ (NSColor*) color:(NSColor*)color withAdjustedBrightness:(float)factor;
#endif

// Returns a linear mix between two colors.
// If factor is 0.0 the first color is returned.
// If factor is 1.0 the second color is returned.
// If factor is 0.5 the average between two colors is returned.
#if TARGET_OS_IPHONE
+ (UIColor*) linearMix:(float)factor color1:(UIColor*)color1 color2:(UIColor*)color2;
#else
+ (NSColor*) linearMix:(float)factor color1:(NSColor*)color1 color2:(NSColor*)color2;
#endif


@end
