//  AwfulIconActionItem.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
            
        case AwfulIconActionItemTypeEditPost:
            title = @"Edit Post";
            tintColor = [UIColor colorWithHue:0.068 saturation:0.808 brightness:0.573 alpha:1];
            icon = [UIImage imageNamed:@"edit-post"];
            break;
        
        case AwfulIconActionItemTypeJumpToFirstPage:
            title = @"Jump to First Page";
            tintColor = [UIColor colorWithHue:0.153 saturation:0.111 brightness:0.882 alpha:1];
            icon = [UIImage imageNamed:@"jump-to-first-page"];
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
            
        case AwfulIconActionItemTypeMarkReadUpToHere:
            title = @"Mark Read Up to Here";
            tintColor = [UIColor colorWithHue:0.340 saturation:0.750 brightness:0.690 alpha:1];
            icon = [UIImage imageNamed:@"mark-read-up-to-here"];
            break;

        case AwfulIconActionItemTypeQuotePost:
            title = @"Quote";
            tintColor = [UIColor colorWithWhite:0.325 alpha:1];
            icon = [UIImage imageNamed:@"quote-post"];
            break;

        case AwfulIconActionItemTypeRapSheet:
            title = @"Rap Sheet";
            tintColor = [UIColor colorWithHue:0.117 saturation:1.0 brightness:0.96 alpha:1];
            icon = [UIImage imageNamed:@"rap-sheet"];
            break;
        
        case AwfulIconActionItemTypeRemoveBookmark:
            title = @"Remove Bookmark";
            tintColor = [UIColor colorWithHue:0.023 saturation:0.85 brightness:0.835 alpha:1];
            icon = [UIImage imageNamed:@"remove-bookmark"];
            break;
            
        case AwfulIconActionItemTypeSendPrivateMessage:
            title = @"Send PM";
            tintColor = [UIColor colorWithHue:0.133 saturation:0.78 brightness:0.89 alpha:1];
            icon = [UIImage imageNamed:@"send-private-message"];
            break;
            
        case AwfulIconActionItemTypeSingleUsersPosts:
            title = @"Just Their Posts";
            tintColor = [UIColor colorWithHue:0.523 saturation:0.831 brightness:0.675 alpha:1];
            icon = [UIImage imageNamed:@"single-users-posts"];
            break;
        
        case AwfulIconActionItemTypeUserProfile:
            title = @"Profile";
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
