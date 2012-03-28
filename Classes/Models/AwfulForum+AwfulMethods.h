//
//  AwfulForum+AwfulMethods.h
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForum.h"

@interface AwfulForum (AwfulMethods)

+(NSMutableArray *)parseForums : (NSData *)data;
+(AwfulForum *)getForumWithID : (NSString *)forumID fromCurrentList : (NSMutableArray *)currentList;

@end
