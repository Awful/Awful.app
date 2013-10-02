//  AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTheme.h"
#import "AwfulSettings.h"
#import "AwfulThemeLoader.h"
#import <objc/runtime.h>

@implementation AwfulTheme

+ (instancetype)currentTheme
{
	if ([AwfulSettings settings].darkTheme) {
		return [[AwfulThemeLoader sharedLoader] themeNamed:@"dark"];
	}
	else {
		return [AwfulThemeLoader sharedLoader].defaultTheme;
	}
}

+ (instancetype)currentThemeForForumId:(NSString*)forumId
{
	NSString *specificThemeName = [[AwfulSettings settings] themeNameForForumID:forumId];
    if (specificThemeName) {
        return [[AwfulThemeLoader sharedLoader] themeNamed:specificThemeName];
    }
	else {
		return self.currentTheme;
	}
}


- (id)initWithName:(NSString *)name dictionary:(NSDictionary *)dictionary
{
    if (!(self = [super init])) return nil;
    _name = [name copy];
    _dictionary = [dictionary copy];
    return self;
}

- (NSString *)descriptiveName
{
    // Intentionally bypassing the parentTheme chain.
    return _dictionary[@"description"];
}

- (UIColor *)descriptiveColor
{
    return self[@"descriptiveColor"];
}

- (BOOL)forumSpecific
{
    return !![self objectForKey:@"relevantForumID"];
}

- (id)objectForKey:(id)key
{
    return _dictionary[key] ?: [self.parentTheme objectForKey:key];
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    if ([key hasSuffix:@"Color"]) {
        return [self colorForKey:key];
    } else if ([key hasSuffix:@"CSS"]) {
        return [self stylesheetForKey:key];
    }
    return [self objectForKey:key];
}

- (UIColor *)colorForKey:(NSString *)key
{
    NSString *value = [self objectForKey:key];
    return ColorWithHexCode(value) ?: ColorWithPatternImageNamed(value);
}

static UIColor * ColorWithHexCode(NSString *hexCode)
{
	if (hexCode == nil) return nil;
	
    NSMutableString *hexString = [NSMutableString stringWithString:hexCode];
    [hexString replaceOccurrencesOfString:@"#" withString:@"" options:0 range:NSMakeRange(0, hexString.length)];
    CFStringTrimWhitespace((__bridge CFMutableStringRef)hexString);
    if (!(hexString.length == 6 || hexString.length == 8)) return nil;
    
    unsigned int red, green, blue, alpha = 255;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    if (hexString.length > 6) {
        [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(6, 2)]] scanHexInt:&alpha];
    }
    return [UIColor colorWithRed:(red / 255.) green:(green / 255.) blue:(blue / 255.) alpha:(alpha / 255.)];
}

static UIColor * ColorWithPatternImageNamed(NSString *name)
{
    return [UIColor colorWithPatternImage:[UIImage imageNamed:name]];
}

- (NSString *)stylesheetForKey:(NSString *)key
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:[self objectForKey:key] withExtension:nil];
    NSError *error;
    NSString *stylesheet = [NSString stringWithContentsOfURL:url usedEncoding:nil error:&error];
    NSAssert(stylesheet, @"could not load stylesheet in theme %@ for key %@; error: %@", self.name, key, error);
    return stylesheet;
}

- (BOOL)isEqual:(AwfulTheme *)other
{
    if (![other isKindOfClass:[AwfulTheme class]]) return NO;
    return [self.name isEqualToString:other.name];
}

- (NSUInteger)hash
{
    return self.name.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p %@>", self.class, self, self.name];
}

@end
