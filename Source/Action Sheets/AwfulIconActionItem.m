//
//  AwfulIconActionItem.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulIconActionItem.h"

@implementation AwfulIconActionItem

- (id)initWithTitle:(NSString *)title
               icon:(UIImage *)icon
          tintColor:(UIColor *)tintColor
             action:(void (^)(void))action
{
    if (!(self = [super init])) return nil;
    self.title = title;
    self.icon = icon;
    self.tintColor = tintColor;
    self.action = action;
    return self;
}

+ (instancetype)itemWithType:(AwfulIconActionItemType)type action:(void (^)(void))action
{
    NSString *title;
    UIColor *tintColor;
    UIImage *icon;
    switch (type) {
        case AwfulIconActionItemTypeAddBookmark:
            title = @"Add Bookmark";
            tintColor = [UIColor colorWithHue:0.206 saturation:0.816 brightness:0.639 alpha:1];
            icon = [UIImage imageNamed:@"add-bookmark"];
            break;
        
        case AwfulIconActionItemTypeCopyURL:
            title = @"Copy URL";
            tintColor = [UIColor colorWithHue:0.590 saturation:0.630 brightness:0.890 alpha:1];
            icon = [UIImage imageNamed:@"copy-url"];
            break;
        
        case AwfulIconActionItemTypeJumpToFirstPage:
            title = @"Jump to First Page";
            tintColor = [UIColor colorWithHue:0.153 saturation:0.111 brightness:0.882 alpha:1];
            icon = [UIImage imageNamed:@"jump-to-first-page.png"];
            break;
        
        case AwfulIconActionItemTypeJumpToLastPage:
            title = @"Jump to Last Page";
            tintColor = [UIColor colorWithHue:0.115 saturation:0.113 brightness:0.451 alpha:1];
            icon = [UIImage imageNamed:@"jump-to-last-page"];
            break;
        
        case AwfulIconActionItemTypeMarkAsUnread:
            title = @"Mark as Unread";
            tintColor = [UIColor colorWithHue:0.762 saturation:0.821 brightness:0.831 alpha:1];
            icon = [UIImage imageNamed:@"mark-as-unread"];
            break;
        
        case AwfulIconActionItemTypeRemoveBookmark:
            title = @"Remove Bookmark";
            tintColor = [UIColor colorWithHue:0.023 saturation:0.845 brightness:0.835 alpha:1];
            icon = [UIImage imageNamed:@"remove-bookmark"];
            break;
        
        case AwfulIconActionItemTypeUserProfile:
            title = @"User Profile";
            tintColor = [UIColor colorWithHue:0.633 saturation:0.055 brightness:0.718 alpha:1];
            icon = [UIImage imageNamed:@"user-profile"];
            break;
        
        case AwfulIconActionItemTypeVote:
            title = @"Vote";
            tintColor = [UIColor colorWithHue:0.081 saturation:0.843 brightness:0.898 alpha:1];
            icon = [UIImage imageNamed:@"vote"];
            break;
    }
    return [[self alloc] initWithTitle:title icon:icon tintColor:tintColor action:action];
}

@end
