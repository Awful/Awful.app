//  AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTheme.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulSettings.h"
#import "AwfulThemeLoader.h"

@implementation AwfulTheme

+ (instancetype)currentTheme
{
	if ([AwfulSettings sharedSettings].darkTheme) {
		return [[AwfulThemeLoader sharedLoader] themeNamed:@"dark"];
	}
	else {
		return [AwfulThemeLoader sharedLoader].defaultTheme;
	}
}

+ (instancetype)currentThemeForForum:(AwfulForum *)forum
{
    if (!forum) {
        return self.currentTheme;
    }
	NSString *specificThemeName = [[AwfulSettings sharedSettings] themeNameForForumID:forum.forumID];
    if (specificThemeName) {
        return [[AwfulThemeLoader sharedLoader] themeNamed:specificThemeName];
    } else {
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
    } else {
        return [self objectForKey:key];
    }
}

- (UIColor *)colorForKey:(NSString *)key
{
    NSString *value = [self objectForKey:key];
    if (!value) return nil;
    return [UIColor awful_colorWithHexCode:value] ?: ColorWithPatternImageNamed(value);
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

- (UIScrollViewIndicatorStyle)scrollIndicatorStyle
{
	NSString *styleString = self[@"scrollIndicatorStyle"];
	if ([styleString caseInsensitiveCompare:@"white"] == NSOrderedSame) {
		return UIScrollViewIndicatorStyleWhite;
	} else if ([styleString caseInsensitiveCompare:@"black"] == NSOrderedSame) {
		return UIScrollViewIndicatorStyleBlack;
	} else {
		return UIScrollViewIndicatorStyleDefault;
	}
}

- (UIKeyboardAppearance)keyboardAppearance
{
    NSString *string = self[@"keyboardAppearance"];
    if ([string caseInsensitiveCompare:@"dark"] == NSOrderedSame) {
        return UIKeyboardAppearanceDark;
    } else if ([string caseInsensitiveCompare:@"light"] == NSOrderedSame) {
        return UIKeyboardAppearanceLight;
    } else {
        return UIKeyboardAppearanceDefault;
    }
}

@end
