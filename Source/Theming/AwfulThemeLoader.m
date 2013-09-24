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

+ (instancetype)sharedLoader
{
    static AwfulThemeLoader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
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

- (NSArray *)themesForForumWithID:(NSString *)forumID
{
    NSMutableArray *themes = [NSMutableArray new];
    for (AwfulTheme *theme in _themes) {
        NSString *relevantForumID = theme[@"relevantForumID"];
        if (!relevantForumID || [relevantForumID isEqualToString:forumID]) {
            [themes addObject:theme];
        }
    }
    return themes;
}

@end
