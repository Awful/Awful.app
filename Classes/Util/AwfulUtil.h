//
//  AwfulUtil.h
//  Awful
//
//  Created by Sean Berry on 7/30/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    AwfulStarCategoryBlue = 0,
    AwfulStarCategoryRed,
    AwfulStarCategoryYellow,
    AwfulStarCategoryNone
} AwfulStarCategory;

@interface AwfulUtil : NSObject

+(void)requestFailed : (NSError *)error;
+(NSString *)getDocsDir;
+(float)getThreadCellHeight;
+(NSMutableArray *)newThreadListForForumId : (NSString *)forum_id;
+(void)saveThreadList : (NSMutableArray *)list forForumId : (NSString *)forum_id;

@end

float getWidth();