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

// Login view

@property (readonly, nonatomic) UIColor *loginViewBackgroundColor;
@property (readonly, nonatomic) UIColor *loginViewForgotLinkTextColor;

// Forum list

@property (readonly, nonatomic) UIColor *forumListBackgroundColor;
@property (readonly, nonatomic) UIColor *forumListSeparatorColor;
@property (readonly, nonatomic) UIColor *forumListHeaderTextColor;
@property (readonly, nonatomic) UIColor *forumCellBackgroundColor;
@property (readonly, nonatomic) UIColor *forumCellSubforumBackgroundColor;
@property (readonly, nonatomic) UIImage *forumCellExpandButtonNormalImage;
@property (readonly, nonatomic) UIImage *forumCellExpandButtonSelectedImage;
@property (readonly, nonatomic) UIImage *forumCellFavoriteButtonNormalImage;
@property (readonly, nonatomic) UIImage *forumCellFavoriteButtonSelectedImage;

// Thread list

@property (readonly, nonatomic) UIColor *threadListSeparatorColor;
@property (readonly, nonatomic) UIColor *threadListOriginalPosterTextColor;
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
@property (readonly, nonatomic) UIColor *settingsViewFooterTextColor;

@end


// Sent to the default center whenever the current theme changes.
extern NSString * const AwfulThemeDidChangeNotification;
