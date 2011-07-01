//
//  AwfulForum.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulForum : NSObject <NSCoding> {
    NSString *_forumID;
    NSString *_name;
    NSString *_parentForumID;
    NSString *_acronym;
}

@property (nonatomic, retain) NSString *forumID;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *parentForumID;
@property (nonatomic, retain) NSString *acronym;

+(id)awfulForumFromID : (NSString *)forum_id;
+(NSMutableArray *)getForumsList;

@end
