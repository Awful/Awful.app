//  AwfulIconActionItem.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

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
    AwfulIconActionItemTypeRemoveBookmark,
    AwfulIconActionItemTypeSendPrivateMessage,
    AwfulIconActionItemTypeSingleUsersPosts,
    AwfulIconActionItemTypeUserProfile,
    AwfulIconActionItemTypeVote,
};


@interface AwfulIconActionItem : NSObject

- (id)initWithTitle:(NSString *)title
               icon:(UIImage *)icon
          tintColor:(UIColor *)tintColor
             action:(void (^)(void))action;

@property (copy, nonatomic) NSString *title;
@property (nonatomic) UIImage *icon;
@property (nonatomic) UIColor *tintColor;
@property (copy, nonatomic) void (^action)(void);

+ (instancetype)itemWithType:(AwfulIconActionItemType)type action:(void (^)(void))action;

@end
