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
            tintColor = [UIColor colorWithRed:0.463 green:0.702 blue:0.357 alpha:1.0];
            icon = [UIImage imageNamed:@"add-bookmark"];
            break;
        
        case AwfulIconActionItemTypeCopyURL:
            title = @"Copy\nURL";
            tintColor = [UIColor colorWithRed:0.471 green:0.588 blue:0.725 alpha:1.0];
            icon = [UIImage imageNamed:@"copy-url"];
            break;
            
        case AwfulIconActionItemTypeEditPost:
            title = @"Edit\nPost";
            tintColor = [UIColor colorWithRed:0.788 green:0.549 blue:0.388 alpha:1.0];
            icon = [UIImage imageNamed:@"edit-post"];
            break;
        
        case AwfulIconActionItemTypeJumpToFirstPage:
            title = @"Jump to First Page";
            tintColor = [UIColor colorWithRed:0.565 green:0.545 blue:0.506 alpha:1.0];
            icon = [UIImage imageNamed:@"jump-to-first-page"];
            break;
        
        case AwfulIconActionItemTypeJumpToLastPage:
            title = @"Jump to Last Page";
            tintColor = [UIColor colorWithRed:0.565 green:0.545 blue:0.506 alpha:1.0];
            icon = [UIImage imageNamed:@"jump-to-last-page"];
            break;
        
        case AwfulIconActionItemTypeMarkAsUnread:
            title = @"Mark as Unread";
            tintColor = [UIColor colorWithRed:0.561 green:0.431 blue:0.667 alpha:1.0];
            icon = [UIImage imageNamed:@"mark-as-unread"];
            break;
            
        case AwfulIconActionItemTypeMarkReadUpToHere:
            title = @"Mark Read Up to Here";
            tintColor = [UIColor colorWithRed:0.463 green:0.702 blue:0.357 alpha:1.0];
            icon = [UIImage imageNamed:@"mark-read-up-to-here"];
            break;

        case AwfulIconActionItemTypeQuotePost:
            title = @"Quote\nPost";
            tintColor = [UIColor colorWithRed:0.698 green:0.698 blue:0.698 alpha:1.0];
            icon = [UIImage imageNamed:@"quote-post"];
            break;

        case AwfulIconActionItemTypeRapSheet:
            title = @"Rap\nSheet";
            tintColor = [UIColor colorWithRed:0.863 green:0.549 blue:0.243 alpha:1.0];
            icon = [UIImage imageNamed:@"rap-sheet"];
            break;
        
        case AwfulIconActionItemTypeRemoveBookmark:
            title = @"Remove Bookmark";
            tintColor = [UIColor colorWithRed:0.831 green:0.333 blue:0.239 alpha:1.0];
            icon = [UIImage imageNamed:@"remove-bookmark"];
            break;
            
        case AwfulIconActionItemTypeSendPrivateMessage:
            title = @"Send\nPM";
            tintColor = [UIColor colorWithRed:0.51 green:0.631 blue:0.604 alpha:1.0];
            icon = [UIImage imageNamed:@"send-private-message"];
            break;
            
        case AwfulIconActionItemTypeSingleUsersPosts:
            title = @"Just Their Posts";
            tintColor = [UIColor colorWithRed:0.416 green:0.561 blue:0.584 alpha:1.0];
            icon = [UIImage imageNamed:@"single-users-posts"];
            break;
        
        case AwfulIconActionItemTypeUserProfile:
            title = @"User\nProfile";
            tintColor = [UIColor colorWithRed:0.62 green:0.627 blue:0.667 alpha:1.0];
            icon = [UIImage imageNamed:@"user-profile"];
            break;
        
        case AwfulIconActionItemTypeVote:
            title = @"Vote\nThread";
            tintColor = [UIColor colorWithRed:0.835 green:0.749 blue:0.353 alpha:1.0];
            icon = [UIImage imageNamed:@"vote"];
            break;
    }
    return [[self alloc] initWithTitle:title icon:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] tintColor:tintColor action:action];
}

@end
