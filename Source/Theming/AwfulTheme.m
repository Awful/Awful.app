//
//  AwfulTheme.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThemeDidChangeNotification
                                                                object:self];
        });
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

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    LIGHT(UIActivityIndicatorViewStyleGray);
    DARK(UIActivityIndicatorViewStyleWhite);
}

- (UIColor *)disclosureIndicatorColor
{
    LIGHT([UIColor grayColor]);
    DARK([UIColor darkGrayColor]);
}

- (UIColor *)disclosureIndicatorHighlightedColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor blackColor]);
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

#pragma mark - Leper's Colony

- (UIColor *)lepersColonyBackgroundColor
{
    DEFAULT(self.threadListBackgroundColor);
}

- (UIColor *)lepersColonySeparatorColor
{
    DEFAULT(self.threadListSeparatorColor);
}

- (UIColor *)lepersColonyTextColor
{
    DEFAULT(self.forumCellTextColor);
}

- (UIColor *)lepersColonyCellBackgroundTopColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor colorWithWhite:0.192 alpha:1]);
}

- (UIColor *)lepersColonyCellBackgroundDividerShadowColor
{
    DEFAULT([UIColor colorWithWhite:0.5 alpha:0.2]);
}

- (UIColor *)lepersColonyCellBackgroundBottomColor
{
    LIGHT([UIColor colorWithWhite:0.969 alpha:1]);
    DARK([UIColor colorWithWhite:0.07 alpha:1]);
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

- (UIColor *)threadCellTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)threadCellClosedThreadColor
{
    DEFAULT([UIColor grayColor]);
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
    DEFAULT(self.disclosureIndicatorColor);
}

- (UIColor *)threadListUnreadBadgeOrangeColor
{
    DEFAULT([UIColor colorWithHue:0.104 saturation:1 brightness:0.886 alpha:1]);
}

- (UIColor *)threadListUnreadBadgeRedColor
{
    DEFAULT([UIColor colorWithHue:0.992 saturation:0.872 brightness:0.706 alpha:1]);
}

- (UIColor *)threadListUnreadBadgeYellowColor
{
    LIGHT([UIColor colorWithHue:0.164 saturation:0.511 brightness:0.875 alpha:1]);
    DARK([UIColor colorWithHue:0.166 saturation:0.778 brightness:0.741 alpha:1]);
}

- (UIColor *)threadListUnreadBadgeBlueColor
{
    DEFAULT([UIColor colorWithHue:0.580 saturation:0.639 brightness:0.576 alpha:1]);
}

- (UIColor *)threadListUnreadBadgeHighlightedColor
{
    DEFAULT([UIColor whiteColor]);
}

- (UIColor *)threadListUnreadBadgeOrangeOffColor
{
    DEFAULT([self.threadListUnreadBadgeOrangeColor colorWithAlphaComponent:0.5]);
}

- (UIColor *)threadListUnreadBadgeRedOffColor
{
    DEFAULT([self.threadListUnreadBadgeRedColor colorWithAlphaComponent:0.5]);
}

- (UIColor *)threadListUnreadBadgeYellowOffColor
{
    DEFAULT([self.threadListUnreadBadgeYellowColor colorWithAlphaComponent:0.5]);
}

- (UIColor *)threadListUnreadBadgeBlueOffColor
{
    DEFAULT([self.threadListUnreadBadgeBlueColor colorWithAlphaComponent:0.5]);
}

#pragma mark - Posts view

- (UIColor *)postsViewBackgroundColor
{
    LIGHT([UIColor colorWithWhite:0.82 alpha:1]);
    DARK([UIColor colorWithWhite:0.075 alpha:1]);
}

- (UIColor *)postsViewTopBarMarginColor
{
    DEFAULT([UIColor colorWithWhite:0.714 alpha:1]);
}

- (UIColor *)postsViewTopBarButtonBackgroundColor
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

- (UIColor *)postsViewPullUpForNextPageTextAndArrowColor
{
    LIGHT([UIColor grayColor]);
    DARK([UIColor lightGrayColor]);
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

#pragma mark - Private Messages list

- (UIColor *)messageListSubjectTextColor
{
    DEFAULT(self.threadCellTextColor);
}

- (UIColor *)messageListUsernameTextColor
{
    DEFAULT(self.threadCellPagesTextColor);
}

- (UIColor *)messageListCellBackgroundColor
{
    DEFAULT(self.threadCellBackgroundColor);
}

- (UIColor *)messageListCellSeparatorColor
{
    DEFAULT(self.threadListSeparatorColor);
}

- (UIColor *)messageListBackgroundColor
{
    DEFAULT(self.threadListBackgroundColor);
}

- (UIColor *)messageListNeedPlatinumTextColor
{
    DEFAULT(self.forumCellTextColor);
}

- (UIColor *)messageListNeedPlatinumBackgroundColor
{
    DEFAULT(self.messageListBackgroundColor);
}

#pragma mark - Private Message compose view

- (UIColor *)messageComposeFieldLabelColor
{
    LIGHT([UIColor grayColor]);
    DARK([UIColor lightGrayColor]);
}

- (UIColor *)messageComposeFieldTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)messageComposeFieldBackgroundColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor blackColor]);
}

- (UIColor *)messageComposeFieldSeparatorColor
{
    DEFAULT([UIColor colorWithWhite:0.8 alpha:1]);
}

#pragma mark - Post icon picker

- (UIColor *)postIconPickerBackgroundColor
{
    LIGHT([UIColor colorWithWhite:0.788 alpha:1]);
    DARK([UIColor colorWithWhite:0.442 alpha:1]);
}

#pragma mark - Settings view

- (UIColor *)settingsViewBackgroundColor
{
    LIGHT([UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1]);
    DARK(self.postsViewBackgroundColor);
}

- (UIColor *)settingsViewHeaderTextColor
{
    LIGHT([UIColor colorWithRed:0.265 green:0.294 blue:0.367 alpha:1]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)settingsViewHeaderShadowColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor grayColor]);
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
    DARK(self.settingsViewBackgroundColor);
}

- (UIColor *)settingsCellTextColor
{
    LIGHT([UIColor blackColor]);
    DARK([UIColor whiteColor]);
}

- (UIColor *)settingsCellCurrentValueTextColor
{
    LIGHT([UIColor colorWithHue:0.607 saturation:0.568 brightness:0.518 alpha:1]);
    DARK([UIColor colorWithHue:0.584 saturation:0.570 brightness:1.000 alpha:1]);
}

- (UIColor *)settingsCellSwitchOnTintColor
{
    DEFAULT(nil);
}

- (UIColor *)settingsCellSeparatorColor
{
    LIGHT(nil);
    DARK(self.forumListSeparatorColor);
}

#pragma mark - Licenses view

- (UIColor *)licensesViewBackgroundColor
{
    LIGHT([UIColor whiteColor]);
    DARK([UIColor blackColor]);
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
