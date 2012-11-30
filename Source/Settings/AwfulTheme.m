//
//  AwfulTheme.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTheme.h"
#import "AwfulSettings.h"

@interface AwfulTheme ()

@property (getter=isDark, nonatomic) BOOL dark;

@end


@implementation AwfulTheme

+ (AwfulTheme *)currentTheme
{
    static AwfulTheme *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    _dark = [AwfulSettings settings].darkTheme;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    return self;
}

- (void)settingsChanged:(NSNotification *)note
{
    NSArray *changed = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([changed containsObject:AwfulSettingsKeys.darkTheme]) {
        self.dark = [AwfulSettings settings].darkTheme;
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThemeDidChangeNotification
                                                            object:self];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulSettingsDidChangeNotification
                                                  object:nil];
}

#define LIGHT(a) if (!self.dark) return a
#define DARK(b) return b
#define DEFAULT(c) return c

#pragma mark - Table views

- (UITableViewCellSelectionStyle)cellSelectionStyle
{
    LIGHT(UITableViewCellSelectionStyleBlue);
    DARK(UITableViewCellSelectionStyleGray);
}

#pragma mark - Login view

- (UIColor *)loginViewBackgroundColor
{
    DEFAULT([UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1]);
}

- (UIColor *)loginViewForgotLinkTextColor
{
    DEFAULT([UIColor colorWithHue:0.584 saturation:0.960 brightness:0.388 alpha:1]);
}

#pragma mark - Forum list


- (UIColor *)forumListBackgroundColor
{
    DEFAULT([UIColor colorWithWhite:0.494 alpha:1]);
}

- (UIColor *)forumListHeaderBackgroundColor
{
    LIGHT([UIColor colorWithPatternImage:[UIImage imageNamed:@"forum-header-light.png"]]);
    DARK([UIColor colorWithPatternImage:[UIImage imageNamed:@"forum-header-dark.png"]]);
}

- (UIColor *)forumListSeparatorColor
{
    LIGHT([UIColor colorWithWhite:0.95 alpha:1]);
    DARK([UIColor colorWithWhite:0.19 alpha:1]);
}

- (UIColor *)forumListHeaderTextColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor colorWithWhite:0.86 alpha:1.000]);
}

- (UIColor *)forumCellTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)forumCellBackgroundColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor colorWithWhite:0.07 alpha:1]);
}

- (UIColor *)forumCellSubforumBackgroundColor
{
    LIGHT([UIColor colorWithWhite:0.95 alpha:1]);
    DARK([UIColor colorWithWhite:0.12 alpha:1]);
}

- (UIImage *)forumCellExpandButtonNormalImage
{
    LIGHT([UIImage imageNamed:@"forum-arrow-right.png"]);
    DARK([UIImage imageNamed:@"forum-arrow-right-dark.png"]);
}

- (UIImage *)forumCellExpandButtonSelectedImage
{
    LIGHT([UIImage imageNamed:@"forum-arrow-down.png"]);
    DARK([UIImage imageNamed:@"forum-arrow-down-dark.png"]);
}

- (UIImage *)forumCellFavoriteButtonNormalImage
{
    LIGHT([UIImage imageNamed:@"star-off.png"]);
    DARK([UIImage imageNamed:@"star-off-dark.png"]);
}

- (UIImage *)forumCellFavoriteButtonSelectedImage
{
    DEFAULT([UIImage imageNamed:@"star-on.png"]);
}

#pragma mark - Favorites

- (UIColor *)favoritesBackgroundColor
{
    DEFAULT(self.forumCellBackgroundColor);
}

- (UIColor *)favoritesSeparatorColor
{
    DEFAULT(self.forumListSeparatorColor);
}

- (UIColor *)noFavoritesTextColor
{
    LIGHT([UIColor grayColor]);
    DARK([UIColor whiteColor]);
}

#pragma mark - Thread list

- (UIColor *)threadListBackgroundColor
{
    DEFAULT(self.threadCellBackgroundColor);
}

- (UIColor *)threadCellBackgroundColor
{
    LIGHT([UIColor whiteColor]);
    DARK(self.forumCellBackgroundColor);
}

- (UIColor *)threadCellBlueBackgroundColor
{
    LIGHT([UIColor colorWithHue:0.583 saturation:0.106 brightness:0.961 alpha:1]);
    DARK([UIColor colorWithHue:0.583 saturation:0.302 brightness:0.35 alpha:1]);
}

- (UIColor *)threadCellRedBackgroundColor
{
    LIGHT([UIColor colorWithHue:1 saturation:0.091 brightness:0.949 alpha:1]);
    DARK([UIColor colorWithHue:1 saturation:0.305 brightness:0.35 alpha:1]);
}

- (UIColor *)threadCellYellowBackgroundColor
{
    LIGHT([UIColor colorWithHue:0.167 saturation:0.091 brightness:0.949 alpha:1]);
    DARK([UIColor colorWithHue:0.167 saturation:0.3 brightness:0.35 alpha:1]);
}

- (UIColor *)threadCellTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)threadCellPagesTextColor
{
    LIGHT([UIColor grayColor]);
    DARK([UIColor lightGrayColor]);
}

- (UIColor *)threadCellOriginalPosterTextColor
{
    LIGHT([UIColor colorWithHue:0.555 saturation:0.906 brightness:0.667 alpha:1]);
    DARK([UIColor colorWithHue:0.555 saturation:0.3 brightness:0.8 alpha:1]);
}

- (UIColor *)threadListSeparatorColor
{
    LIGHT([UIColor colorWithWhite:0.75 alpha:1]);
    DARK([UIColor colorWithWhite:0.106 alpha:1]);
}

- (UIColor *)threadListUnreadBadgeColor
{
    LIGHT([UIColor colorWithRed:0.169 green:0.408 blue:0.588 alpha:1]);
    DARK([UIColor colorWithRed:0.435 green:0.659 blue:0.769 alpha:1]);
}

- (UIColor *)threadListUnreadBadgeHighlightedColor
{
    DEFAULT([UIColor whiteColor]);
}

- (UIColor *)threadListUnreadBadgeOffColor
{
    LIGHT([UIColor colorWithRed:0.435 green:0.659 blue:0.769 alpha:1]);
    DARK([UIColor colorWithRed:0.169 green:0.408 blue:0.588 alpha:1]);
}

#pragma mark - Posts view

- (UIColor *)postsViewBackgroundColor
{
    LIGHT([UIColor colorWithWhite:0.82 alpha:1]);
    DARK([UIColor colorWithWhite:0.075 alpha:1]);
}

- (UIColor *)postsViewTopBarBackgroundColor
{
    DEFAULT([UIColor colorWithWhite:0.902 alpha:1]);
}

- (UIColor *)postsViewTopBarButtonTextColor
{
    DEFAULT([UIColor colorWithHue:0.590 saturation:0.771 brightness:0.376 alpha:1]);
}

- (UIColor *)postsViewTopBarButtonDisabledTextColor
{
    DEFAULT([UIColor lightGrayColor]);
}

#pragma mark - Reply view

- (UIColor *)replyViewBackgroundColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor blackColor]);
}

- (UIColor *)replyViewTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

#pragma mark - Settings view

- (UIColor *)settingsViewBackgroundColor
{
    LIGHT([UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1]);
    DARK([UIColor blackColor]);
}

- (UIColor *)settingsViewHeaderTextColor
{
    LIGHT([UIColor colorWithRed:0.265 green:0.294 blue:0.367 alpha:1]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)settingsViewHeaderShadowColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor darkGrayColor]);
}

- (UIColor *)settingsViewFooterTextColor
{
    LIGHT([UIColor colorWithRed:0.298 green:0.337 blue:0.424 alpha:1]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)settingsViewFooterShadowColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor darkGrayColor]);
}

- (UIColor *)settingsCellBackgroundColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor darkGrayColor]);
}

- (UIColor *)settingsCellTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)settingsCellCurrentValueTextColor
{
    LIGHT([UIColor colorWithHue:0.607 saturation:0.568 brightness:0.518 alpha:1]);
    DARK([UIColor colorWithHue:0.607 saturation:0.307 brightness:1 alpha:1]);
}

- (UIColor *)settingsCellSwitchOnTintColor
{
    LIGHT(nil);
    DARK([UIColor orangeColor]);
}

- (UIColor *)settingsCellSeparatorColor
{
    LIGHT(nil);
    DARK([UIColor grayColor]);
}

#pragma mark - Licenses view

- (NSString *)licensesViewBackgroundHTMLColor
{
    LIGHT(@"white");
    DARK(@"black");
}

- (NSString *)licensesViewTextHTMLColor
{
    LIGHT(@"black");
    DARK(@"white");
}

- (NSString *)licensesViewLinkHTMLColor
{
    LIGHT(@"blue");
    DARK(@"orange");
}

@end


NSString * const AwfulThemeDidChangeNotification = @"com.awfulapp.Awful.ThemeDidChange";
