//  AwfulThemeLoader.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThemeLoader.h"
#import "AwfulSettings.h"

@implementation AwfulThemeLoader

- (id)init
{
    if ((self = [super init])) {
        NSURL *themesURL = [[NSBundle mainBundle] URLForResource:@"Themes" withExtension:@"plist"];
        NSDictionary *themesDictionary = [NSDictionary dictionaryWithContentsOfURL:themesURL];
        NSMutableArray *themes = [NSMutableArray new];
        NSMutableDictionary *themesByName = [NSMutableDictionary new];
        for (NSString *name in themesDictionary) {
            AwfulTheme *theme = [[AwfulTheme alloc] initWithName:name dictionary:themesDictionary[name]];
            [themes addObject:theme];
            themesByName[name] = theme;
        }
        for (AwfulTheme *theme in themes) {
            if ([theme.name isEqualToString:@"default"]) continue;
            NSString *parentThemeName = theme.dictionary[@"parent"] ?: @"default";
            theme.parentTheme = themesByName[parentThemeName];
        }
        _themes = themes;
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
    for (AwfulTheme *theme in self.themes) {
        if ([theme.name isEqualToString:themeName]) {
            return theme;
        }
    }
    return nil;
}

- (NSArray *)themesForForumWithID:(NSString *)forumID
{
    NSMutableArray *themes = [NSMutableArray new];
    NSArray *ubiquitousThemeNames = [AwfulSettings sharedSettings].ubiquitousThemeNames;
    for (AwfulTheme *theme in self.themes) {
        NSString *relevantForumID = theme[@"relevantForumID"];
        if (!relevantForumID || [relevantForumID isEqualToString:forumID] || [ubiquitousThemeNames containsObject:theme.name]) {
            [themes addObject:theme];
        }
    }
    return themes;
}

@end
