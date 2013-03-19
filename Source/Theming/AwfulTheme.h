//
//  AwfulTheme.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>

@interface AwfulTheme : NSObject

// Singleton instance.
+ (AwfulTheme *)currentTheme;

// Table views

@property (readonly, nonatomic) UITableViewCellSelectionStyle cellSelectionStyle;
@property (readonly, nonatomic) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (readonly, nonatomic) UIColor *disclosureIndicatorColor;
@property (readonly, nonatomic) UIColor *disclosureIndicatorHighlightedColor;

// Login view

@property (readonly, nonatomic) UIColor *loginViewBackgroundColor;
@property (readonly, nonatomic) UIColor *loginViewForgotLinkTextColor;

// Forum list

@property (readonly, nonatomic) UIColor *forumListBackgroundColor;
@property (readonly, nonatomic) UIColor *forumListSeparatorColor;
@property (readonly, nonatomic) UIColor *forumListHeaderBackgroundColor;
@property (readonly, nonatomic) UIColor *forumListHeaderTextColor;
@property (readonly, nonatomic) UIColor *forumCellTextColor;
@property (readonly, nonatomic) UIColor *forumCellBackgroundColor;
@property (readonly, nonatomic) UIColor *forumCellSubforumBackgroundColor;
@property (readonly, nonatomic) UIImage *forumCellExpandButtonNormalImage;
@property (readonly, nonatomic) UIImage *forumCellExpandButtonSelectedImage;
@property (readonly, nonatomic) UIImage *forumCellFavoriteButtonNormalImage;
@property (readonly, nonatomic) UIImage *forumCellFavoriteButtonSelectedImage;

// Leper's Colony

@property (readonly, nonatomic) UIColor *lepersColonyBackgroundColor;
@property (readonly, nonatomic) UIColor *lepersColonySeparatorColor;
@property (readonly, nonatomic) UIColor *lepersColonyTextColor;
@property (readonly, nonatomic) UIColor *lepersColonyCellBackgroundTopColor;
@property (readonly, nonatomic) UIColor *lepersColonyCellBackgroundDividerShadowColor;
@property (readonly, nonatomic) UIColor *lepersColonyCellBackgroundBottomColor;

// Favorites

@property (readonly, nonatomic) UIColor *favoritesBackgroundColor;
@property (readonly, nonatomic) UIColor *favoritesSeparatorColor;
@property (readonly, nonatomic) UIColor *noFavoritesTextColor;

// Thread list

@property (readonly, nonatomic) UIColor *threadListBackgroundColor;
@property (readonly, nonatomic) UIColor *threadCellBackgroundColor;
@property (readonly, nonatomic) UIColor *threadCellBlueBackgroundColor;
@property (readonly, nonatomic) UIColor *threadCellRedBackgroundColor;
@property (readonly, nonatomic) UIColor *threadCellYellowBackgroundColor;
@property (readonly, nonatomic) UIColor *threadCellTextColor;
@property (readonly, nonatomic) UIColor *threadCellClosedThreadColor;
@property (readonly, nonatomic) UIColor *threadCellPagesTextColor;
@property (readonly, nonatomic) UIColor *threadCellOriginalPosterTextColor;
@property (readonly, nonatomic) UIColor *threadListSeparatorColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeBlueColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeRedColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeYellowColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeHighlightedColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeBlueOffColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeRedOffColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeYellowOffColor;

// Posts view

@property (readonly, nonatomic) UIColor *postsViewBackgroundColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarMarginColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarButtonBackgroundColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarButtonTextColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarButtonDisabledTextColor;
@property (readonly, nonatomic) UIColor *postsViewPullUpForNextPageTextAndArrowColor;

// Reply view

@property (readonly, nonatomic) UIColor *replyViewBackgroundColor;
@property (readonly, nonatomic) UIColor *replyViewTextColor;

// Private Messages list

@property (readonly, nonatomic) UIColor *messageListSubjectTextColor;
@property (readonly, nonatomic) UIColor *messageListUsernameTextColor;
@property (readonly, nonatomic) UIColor *messageListCellBackgroundColor;
@property (readonly, nonatomic) UIColor *messageListCellSeparatorColor;
@property (readonly, nonatomic) UIColor *messageListBackgroundColor;

// Private Message compose view

@property (readonly, nonatomic) UIColor *messageComposeFieldLabelColor;
@property (readonly, nonatomic) UIColor *messageComposeFieldTextColor;
@property (readonly, nonatomic) UIColor *messageComposeFieldBackgroundColor;
@property (readonly, nonatomic) UIColor *messageComposeFieldSeparatorColor;

// Post icon picker

@property (readonly, nonatomic) UIColor *postIconPickerBackgroundColor;

// Settings view

@property (readonly, nonatomic) UIColor *settingsViewBackgroundColor;
@property (readonly, nonatomic) UIColor *settingsViewHeaderTextColor;
@property (readonly, nonatomic) UIColor *settingsViewHeaderShadowColor;
@property (readonly, nonatomic) UIColor *settingsViewFooterTextColor;
@property (readonly, nonatomic) UIColor *settingsViewFooterShadowColor;
@property (readonly, nonatomic) UIColor *settingsCellBackgroundColor;
@property (readonly, nonatomic) UIColor *settingsCellTextColor;
@property (readonly, nonatomic) UIColor *settingsCellCurrentValueTextColor;
@property (readonly, nonatomic) UIColor *settingsCellSwitchOnTintColor;
@property (readonly, nonatomic) UIColor *settingsCellSeparatorColor;

// Licenses view

@property (readonly, nonatomic) UIColor *licensesViewBackgroundColor;
@property (readonly, nonatomic) NSString *licensesViewTextHTMLColor;
@property (readonly, nonatomic) NSString *licensesViewLinkHTMLColor;

@end


// Sent to the default center whenever the current theme changes.
extern NSString * const AwfulThemeDidChangeNotification;
