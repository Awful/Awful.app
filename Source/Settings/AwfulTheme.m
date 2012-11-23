//
//  AwfulTheme.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTheme.h"

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

#pragma mark - Login view

- (UIColor *)loginViewBackgroundColor
{
    return [UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1];
}

- (UIColor *)loginViewForgotLinkTextColor
{
    return [UIColor colorWithHue:0.584 saturation:0.960 brightness:0.388 alpha:1];
}

#pragma mark - Forum list

- (UIColor *)forumListBackgroundColor
{
    return [UIColor colorWithWhite:0.494 alpha:1];
}

- (UIColor *)forumListSeparatorColor
{
    return [UIColor colorWithWhite:0.94 alpha:1];
}

- (UIColor *)forumListHeaderTextColor
{
    return [UIColor whiteColor];
}

- (UIColor *)forumCellBackgroundColor
{
    return [UIColor whiteColor];
}

- (UIColor *)forumCellSubforumBackgroundColor
{
    return [UIColor colorWithRed:0.922 green:0.922 blue:0.925 alpha:1];
}

- (UIImage *)forumCellExpandButtonNormalImage
{
    return [UIImage imageNamed:@"forum-arrow-right.png"];
}

- (UIImage *)forumCellExpandButtonSelectedImage
{
    return [UIImage imageNamed:@"forum-arrow-down.png"];
}

- (UIImage *)forumCellFavoriteButtonNormalImage
{
    return [UIImage imageNamed:@"star-off.png"];
}

- (UIImage *)forumCellFavoriteButtonSelectedImage
{
    return [UIImage imageNamed:@"star-on.png"];
}

#pragma mark - Thread list

- (UIColor *)threadListSeparatorColor
{
    return [UIColor colorWithWhite:0.75 alpha:1];
}

- (UIColor *)threadListOriginalPosterTextColor
{
    return [UIColor colorWithHue:0.553 saturation:0.198 brightness:0.659 alpha:1];
}

- (UIColor *)threadListUnreadBadgeColor
{
    return [UIColor colorWithRed:0.169 green:0.408 blue:0.588 alpha:1];
}

- (UIColor *)threadListUnreadBadgeHighlightedColor
{
    return [UIColor whiteColor];
}

- (UIColor *)threadListUnreadBadgeOffColor
{
    return [UIColor colorWithRed:0.435 green:0.659 blue:0.769 alpha:1];
}

#pragma mark - Posts view

- (UIColor *)postsViewBackgroundColor
{
    return [UIColor colorWithHue:0.561 saturation:0.107 brightness:0.404 alpha:1];
}

- (UIColor *)postsViewTopBarBackgroundColor
{
    return [UIColor colorWithWhite:0.902 alpha:1];
}

- (UIColor *)postsViewTopBarButtonTextColor
{
    return [UIColor colorWithHue:0.590 saturation:0.771 brightness:0.376 alpha:1];
}

- (UIColor *)postsViewTopBarButtonDisabledTextColor
{
    return [UIColor lightGrayColor];
}

#pragma mark - Reply view

- (UIColor *)replyViewBackgroundColor
{
    return [UIColor whiteColor];
}

- (UIColor *)replyViewTextColor
{
    return [UIColor blackColor];
}

#pragma mark - Settings view

- (UIColor *)settingsViewBackgroundColor
{
    return [UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1];
}

- (UIColor *)settingsViewHeaderTextColor
{
    return [UIColor colorWithRed:0.265 green:0.294 blue:0.367 alpha:1];
}

- (UIColor *)settingsViewFooterTextColor
{
    return [UIColor colorWithRed:0.298 green:0.337 blue:0.424 alpha:1];
}

@end
