//
//  AwfulForum.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulForum : NSObject <NSCoding>

@property (nonatomic, strong) NSString *forumID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *parentForumID;
@property (nonatomic, strong) NSString *acronym;

+(id)awfulForumFromID : (NSString *)forum_id;
+(NSMutableArray *)getForumsList;

@end
