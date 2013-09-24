//  AwfulThemeLoader.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThemeLoader.h"

@implementation AwfulThemeLoader
{
    NSMutableArray *_themes;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    NSURL *themesURL = [[NSBundle mainBundle] URLForResource:@"Themes" withExtension:@"plist"];
    NSDictionary *themesDictionary = [NSDictionary dictionaryWithContentsOfURL:themesURL];
    _themes = [NSMutableArray new];
    for (NSString *name in themesDictionary) {
        [_themes addObject:[[AwfulTheme alloc] initWithName:name dictionary:themesDictionary[name]]];
    }
    for (AwfulTheme *theme in _themes) {
        if ([theme.name isEqualToString:@"default"]) continue;
        NSString *parentThemeName = theme.dictionary[@"parent"] ?: @"default";
        theme.parentTheme = [self themeNamed:parentThemeName];
    }
    return self;
}

- (AwfulTheme *)defaultTheme
{
    return [self themeNamed:@"default"];
}

- (AwfulTheme *)themeNamed:(NSString *)themeName
{
    for (AwfulTheme *theme in _themes) {
        if ([theme.name isEqualToString:themeName]) {
            return theme;
        }
    }
    return nil;
}

@end
