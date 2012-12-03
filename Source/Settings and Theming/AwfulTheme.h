//
//  AwfulTheme.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulTheme : NSObject

// Singleton instance.
+ (AwfulTheme *)currentTheme;

// Table views

@property (readonly, nonatomic) UITableViewCellSelectionStyle cellSelectionStyle;
@property (readonly, nonatomic) UIActivityIndicatorViewStyle activityIndicatorViewStyle;

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
@property (readonly, nonatomic) UIColor *threadCellPagesTextColor;
@property (readonly, nonatomic) UIColor *threadCellOriginalPosterTextColor;
@property (readonly, nonatomic) UIColor *threadListSeparatorColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeHighlightedColor;
@property (readonly, nonatomic) UIColor *threadListUnreadBadgeOffColor;

// Posts view

@property (readonly, nonatomic) UIColor *postsViewBackgroundColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarBackgroundColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarButtonTextColor;
@property (readonly, nonatomic) UIColor *postsViewTopBarButtonDisabledTextColor;

// Reply view

@property (readonly, nonatomic) UIColor *replyViewBackgroundColor;
@property (readonly, nonatomic) UIColor *replyViewTextColor;

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
