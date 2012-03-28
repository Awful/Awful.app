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

@interface AwfulThread : NSObject <NSCoding>

@property (nonatomic, strong) NSString *threadID;
@property (nonatomic, strong) NSString *title;
@property int totalUnreadPosts;
@property int totalReplies;
@property NSUInteger threadRating;
@property AwfulStarCategory starCategory;
@property (nonatomic, strong) NSURL *threadIconImageURL;
@property (nonatomic, strong) NSString *authorName;
@property (nonatomic, strong) NSString *lastPostAuthorName;
@property (nonatomic, strong) NSDate *lastPostDate;
@property BOOL seen;
@property BOOL isStickied;
@property BOOL isLocked;
@property (nonatomic, strong) AwfulForum *forum;

@end
