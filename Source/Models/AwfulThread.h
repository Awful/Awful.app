//  AwfulThread.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "_AwfulThread.h"
@class AwfulUser;

@interface AwfulThread : _AwfulThread

@property (readonly, nonatomic) NSString *firstIconName;
@property (readonly, nonatomic) NSString *secondIconName;

@property (readonly, nonatomic) BOOL beenSeen;

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos;

+ (instancetype)firstOrNewThreadWithThreadID:(NSString *)threadID;

- (NSInteger)numberOfPagesForSingleUser:(AwfulUser *)singleUser;
- (void)setNumberOfPages:(NSInteger)numberOfPages forSingleUser:(AwfulUser *)singleUser;

@end


typedef NS_ENUM(NSUInteger, AwfulStarCategory) {
    AwfulStarCategoryOrange = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
};
