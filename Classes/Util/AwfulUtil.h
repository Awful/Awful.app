//
//  AwfulUtil.h
//  Awful
//
//  Created by Sean Berry on 7/30/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulUtil : NSObject

+(NSString *)getDocsDir;
+(float)getThreadCellHeight;
+(NSMutableArray *)newThreadListForForumId : (NSString *)forum_id;
+(void)saveThreadList : (NSMutableArray *)list forForumId : (NSString *)forum_id;

@end

int getPostsPerPage();
NSString *getUsername();
float getWidth();