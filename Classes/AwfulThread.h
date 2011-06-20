//
//  AwfulThread.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

@class AwfulForum;

#define AwfulThreadRatingIsGold(rating) ((rating) >= 4)
#define AwfulThreadRatingIsShit(rating) ((rating) < 3)

typedef enum {
    AwfulStarCategoryBlue = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
} AwfulStarCategory;

@interface AwfulThread : NSObject <NSCoding> {
    NSString *_threadID;
    NSString *_title;
    int _totalUnreadPosts;
    int _totalReplies;
    NSUInteger _threadRating;
    AwfulStarCategory _starCategory;
    NSURL *_iconURL;
    NSString *_authorName;
    NSString *_lastPostAuthorName;
    BOOL _seen;
    BOOL _isStickied;
    BOOL _isLocked;
    
    AwfulForum *_forum;
}

@property (nonatomic, retain) NSString *threadID;
@property (nonatomic, retain) NSString *title;
@property int totalUnreadPosts;
@property int totalReplies;
@property NSUInteger threadRating;
@property AwfulStarCategory starCategory;
@property (nonatomic, retain) NSURL *iconURL;
@property (nonatomic, retain) NSString *authorName;
@property (nonatomic, retain) NSString *lastPostAuthorName;
@property BOOL seen;
@property BOOL isStickied;
@property BOOL isLocked;
@property (nonatomic, retain) AwfulForum *forum;

@end
