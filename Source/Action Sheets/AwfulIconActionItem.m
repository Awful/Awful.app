//  AwfulIconActionItem.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulIconActionItem.h"

@implementation AwfulIconActionItem

- (id)initWithTitle:(NSString *)title
               icon:(UIImage *)icon
           themeKey:(NSString *)themeKey
             action:(void (^)(void))action
{
    if ((self = [super init])) {
        _title = [title copy];
        _icon = icon;
        _themeKey = [themeKey copy];
        _action = [action copy];
    }
    return self;
}

+ (instancetype)itemWithType:(AwfulIconActionItemType)type action:(void (^)(void))action
{
    NSString *title;
    UIImage *icon;
    NSString *themeKey;
    switch (type) {
        case AwfulIconActionItemTypeAddBookmark:
            title = @"Add Bookmark";
            icon = [UIImage imageNamed:@"add-bookmark"];
            themeKey = @"addBookmarkIconColor";
            break;
        
        case AwfulIconActionItemTypeCopyURL:
            title = @"Copy\nURL";
            icon = [UIImage imageNamed:@"copy-url"];
            themeKey = @"copyURLIconColor";
            break;
            
        case AwfulIconActionItemTypeEditPost:
            title = @"Edit\nPost";
            icon = [UIImage imageNamed:@"edit-post"];
            themeKey = @"editPostIconColor";
            break;
        
        case AwfulIconActionItemTypeJumpToFirstPage:
            title = @"Jump to First Page";
            icon = [UIImage imageNamed:@"jump-to-first-page"];
            themeKey = @"jumpToFirstPageIconColor";
            break;
        
        case AwfulIconActionItemTypeJumpToLastPage:
            title = @"Jump to Last Page";
            icon = [UIImage imageNamed:@"jump-to-last-page"];
            themeKey = @"jumpToLastPageIconColor";
            break;
        
        case AwfulIconActionItemTypeMarkAsUnread:
            title = @"Mark as Unread";
            icon = [UIImage imageNamed:@"mark-as-unread"];
            themeKey = @"markUnreadIconColor";
            break;
            
        case AwfulIconActionItemTypeMarkReadUpToHere:
            title = @"Mark Read Up to Here";
            icon = [UIImage imageNamed:@"mark-read-up-to-here"];
            themeKey = @"markReadUpToHereIconColor";
            break;

        case AwfulIconActionItemTypeQuotePost:
            title = @"Quote\nPost";
            icon = [UIImage imageNamed:@"quote-post"];
            themeKey = @"quoteIconColor";
            break;

        case AwfulIconActionItemTypeRapSheet:
            title = @"Rap\nSheet";
            icon = [UIImage imageNamed:@"rap-sheet"];
            themeKey = @"rapSheetIconColor";
            break;
        
        case AwfulIconActionItemTypeRemoveBookmark:
            title = @"Remove Bookmark";
            icon = [UIImage imageNamed:@"remove-bookmark"];
            themeKey = @"removeBookmarkIconColor";
            break;
            
        case AwfulIconActionItemTypeSendPrivateMessage:
            title = @"Send\nPM";
            icon = [UIImage imageNamed:@"send-private-message"];
            themeKey = @"sendPMIconColor";
            break;
            
        case AwfulIconActionItemTypeSingleUsersPosts:
            title = @"Just Their Posts";
            icon = [UIImage imageNamed:@"single-users-posts"];
            themeKey = @"singleUserIconColor";
            break;
        
        case AwfulIconActionItemTypeUserProfile:
            title = @"User\nProfile";
            icon = [UIImage imageNamed:@"user-profile"];
            themeKey = @"profileIconColor";
            break;
        
        case AwfulIconActionItemTypeVote:
            title = @"Vote\nThread";
            icon = [UIImage imageNamed:@"vote"];
            themeKey = @"voteIconColor";
            break;
    }
    return [[self alloc] initWithTitle:title icon:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] themeKey:themeKey action:action];
}

@end
