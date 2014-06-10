//  AwfulIconActionItem.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

typedef NS_ENUM(NSInteger, AwfulIconActionItemType)
{
    AwfulIconActionItemTypeAddBookmark,
    AwfulIconActionItemTypeCopyURL,
    AwfulIconActionItemTypeEditPost,
    AwfulIconActionItemTypeJumpToFirstPage,
    AwfulIconActionItemTypeJumpToLastPage,
    AwfulIconActionItemTypeMarkAsUnread,
    AwfulIconActionItemTypeMarkReadUpToHere,
    AwfulIconActionItemTypeQuotePost,
    AwfulIconActionItemTypeRapSheet,
    AwfulIconActionItemTypeRemoveBookmark,
    AwfulIconActionItemTypeSendPrivateMessage,
    AwfulIconActionItemTypeSingleUsersPosts,
    AwfulIconActionItemTypeUserProfile,
    AwfulIconActionItemTypeVote,
};

/**
 * An AwfulIconActionItem appears in an action sheet.
 */
@interface AwfulIconActionItem : NSObject

/**
 * Designated initializer.
 */
- (id)initWithTitle:(NSString *)title
               icon:(UIImage *)icon
           themeKey:(NSString *)themeKey
             action:(void (^)(void))action;

@property (copy, nonatomic) NSString *title;
@property (nonatomic) UIImage *icon;
@property (copy, nonatomic) NSString *themeKey;
@property (copy, nonatomic) void (^action)(void);

+ (instancetype)itemWithType:(AwfulIconActionItemType)type action:(void (^)(void))action;

@end
