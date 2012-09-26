//
//  AwfulCSSTemplate.m
//  Awful
//
//  Created by Nolan Waite on 12-06-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCSSTemplate.h"

@interface AwfulCSSTemplate ()

@property (strong, nonatomic) UIColor *navBarTopBorder;
@property (strong, nonatomic) UIColor *navBarTopGradientStart;
@property (strong, nonatomic) UIColor *navBarTopGradientEnd;
@property (strong, nonatomic) UIColor *navBarBottomGradientStart;
@property (strong, nonatomic) UIColor *navBarBottomGradientEnd;

@end

@interface NSString (AwfulRegex)

- (NSString *)awful_firstMatchForRegex:(NSString *)regex
                               options:(NSRegularExpressionOptions)options
                                 group:(NSUInteger)group;

- (NSArray *)awful_firstMatchForRegex:(NSString *)regex
                              options:(NSRegularExpressionOptions)options
                               groups:(NSIndexSet *)groups;

@end

@implementation AwfulCSSTemplate

- (id)initWithURL:(NSURL *)url error:(NSError **)error
{
    self = [super init];
    if (self) {
        _URL = url;
        _CSS = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
        if (!_CSS) {
            return nil;
        }
        [self parseNavBarColors];
    }
    return self;
}

static UIColor *ColorWithHexString(NSString *hexString)
{
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    unsigned int hex;
    BOOL ok = [scanner scanHexInt:&hex];
    if (!ok) {
        return nil;
    }
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1];
}

- (void)parseNavBarColors
{
    static NSString * const SectionRegex =
        @"\\#navbar\\s*  # The #navbar selector with optional whitespace \n"
        @"\\{            # An open brace                                 \n"
        @"[^}]*          # Some non-closing-brace material               \n"
        @"\\}            # And a close brace                             \n";
    
    static NSString * const TopBorderRegex =
        @"border-top-color\\s*  # The attribute we want with optional whitespace \n"
        @":\\s*                 # A colon with optional whitespace               \n"
        @"\\#([A-Fa-f0-9]{6})   # A CSS hexadecimal color, its digits captured   \n";
    
    static NSString * const GradientRegex =
        @"gradient-%@\\s*      # The attribute we want (printf-style) with optional whitespace \n"
        @":\\s*                # A colon with optional whitespace                              \n"
        @"\\#([A-Fa-f0-9]{6})  # A CSS hexadecimal color                                       \n"
        @"\\s+                 # With mandatory whitespace                                     \n"
        @"\\#([A-Fa-f0-9]{6})  # And a second CSS hexadecimal color                            \n";
    
    NSRegularExpressionOptions options = NSRegularExpressionAllowCommentsAndWhitespace;
    
    NSString *navBar = [self.CSS awful_firstMatchForRegex:SectionRegex options:options group:0];
    if (!navBar) {
        return;
    }
    NSString *topBorderHex = [navBar awful_firstMatchForRegex:TopBorderRegex
                                                      options:options
                                                        group:1];
    if (topBorderHex) {
        _navBarTopBorder = ColorWithHexString(topBorderHex);
    }
    
    NSMutableArray *gradientColorStrings = [NSMutableArray new];
    NSIndexSet *oneAndTwo = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)];
    void (^AddStringsOrNulls)(NSString *) = ^(NSString *position) {
        NSString *regex = [NSString stringWithFormat:GradientRegex, position];
        NSArray *strings = [navBar awful_firstMatchForRegex:regex
                                                    options:options
                                                     groups:oneAndTwo];
        if (strings) {
            [gradientColorStrings addObjectsFromArray:strings];
        } else {
            for (int i = 0; i < 2; i++) [gradientColorStrings addObject:[NSNull null]];
        }
    };
    AddStringsOrNulls(@"top");
    AddStringsOrNulls(@"bottom");
    
    static NSString *GradientKeys[] = {
        @"navBarTopGradientStart",
        @"navBarTopGradientEnd",
        @"navBarBottomGradientStart",
        @"navBarBottomGradientEnd",
    };
    [gradientColorStrings enumerateObjectsUsingBlock:^(NSString *s, NSUInteger i, BOOL *stop) {
        if (![s isEqual:[NSNull null]]) {
            UIColor *color = ColorWithHexString(s);
            if (color) {
                [self setValue:color forKey:GradientKeys[i]];
            }
        }
    }];
}

- (UIImage *)navigationBarImageForMetrics:(UIBarMetrics)metrics
{
    CGFloat height = metrics == UIBarMetricsDefault ? 42 : 32;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, height), YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextSetFillColorSpace(context, rgb);
    
    // 1px top border, below status bar.
    CGContextSaveGState(context);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddRect(context, CGRectMake(0, 0, 1, 1));
    CGContextSetFillColorWithColor(context, self.navBarTopBorder.CGColor);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
    
    // Fake two-tone gradient.
    CGContextSaveGState(context);
    CGFloat locations[] = { 0, 0.5, 0.5, 1.0 };
    CGGradientRef gradient = CGGradientCreateWithColors(rgb, [self gradientColors], locations);
    // y-values are so the middle of the gradient lines up with bar button items.
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 1), CGPointMake(1, height + 1), 0);
    CGGradientRelease(gradient);
    CGContextRestoreGState(context);
    
    CGColorSpaceRelease(rgb);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(height, 0, 0, 0)];
}

- (CFArrayRef)gradientColors
{
    return (__bridge CFArrayRef)[NSArray arrayWithObjects:
                                 (id)self.navBarTopGradientStart.CGColor,
                                 (id)self.navBarTopGradientEnd.CGColor,
                                 (id)self.navBarBottomGradientStart.CGColor,
                                 (id)self.navBarBottomGradientEnd.CGColor,
                                 nil];
}

@end

@implementation NSString (AwfulRegex)

static NSTextCheckingResult *FirstMatchForRegex(NSString *pattern,
                                                NSRegularExpressionOptions options,
                                                NSString *string)
{
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:options
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error parsing regex %@: %@", pattern, error);
        return nil;
    }
    return [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
}

- (NSString *)awful_firstMatchForRegex:(NSString *)regex
                               options:(NSRegularExpressionOptions)options
                                 group:(NSUInteger)group
{
    NSTextCheckingResult *result = FirstMatchForRegex(regex, options, self);
    if (!result) {
        return nil;
    }
    if (result.range.location == NSNotFound) {
        return @"";
    }
    return [self substringWithRange:[result rangeAtIndex:group]];
}

- (NSArray *)awful_firstMatchForRegex:(NSString *)regex
                              options:(NSRegularExpressionOptions)options
                               groups:(NSIndexSet *)groups
{
    NSTextCheckingResult *result = FirstMatchForRegex(regex, options, self);
    if (!result) {
        return nil;
    }
    if (result.range.location == NSNotFound) {
        return [NSArray array];
    }
    NSMutableArray *captured = [NSMutableArray new];
    [groups enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
        NSRange range = [result rangeAtIndex:i];
        if (range.location == NSNotFound) {
            [captured addObject:[NSNull null]];
        } else {
            [captured addObject:[self substringWithRange:range]];
        }
    }];
    return captured;
}

@end

@implementation AwfulCSSTemplate (Settings)

+ (AwfulCSSTemplate *)currentTemplate
{
    return CommonCSSLoader([[AwfulSettings settings] darkTheme] ? @"dark" : @"default");
}

+ (AwfulCSSTemplate *)defaultTemplate
{
    return CommonCSSLoader(@"default");
}

static AwfulCSSTemplate *CommonCSSLoader(NSString *basename)
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:basename withExtension:@"css"];
    NSError *error;
    AwfulCSSTemplate *css = [[AwfulCSSTemplate alloc] initWithURL:url error:&error];
    if (!css) {
        NSLog(@"error loading current template %@: %@", url, error);
    }
    return css;
}

@end
