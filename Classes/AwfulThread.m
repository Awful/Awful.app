//
//  AwfulThread.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"
#import "TFHpple.h"
#import "XPathQuery.h"

@implementation AwfulThread

@synthesize threadTitle, threadID, numUnreadPosts, threadRating, threadIcon;
@synthesize threadAuthor, forumTitle, totalReplies, alreadyRead, killedBy;
@synthesize isLocked, isStickied, category;

-(id)init
{
    threadID = nil;
    threadTitle = nil;
    numUnreadPosts = -1; // haven't read it
    threadRating = RATED_NOTHING;
    totalReplies = 0;
    threadIcon = nil;
    threadAuthor = nil;
    alreadyRead = NO;
    forumTitle = nil;
    killedBy = nil;
    isStickied = NO;
    isLocked = NO;
    category = -1;
    return self;
}

-(void)dealloc
{
    [forumTitle release];
    [threadID release];
    [threadTitle release];
    [threadIcon release];
    [threadAuthor release];
    [killedBy release];
    [super dealloc];
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:threadID forKey:@"threadID"];
    [aCoder encodeObject:threadTitle forKey:@"threadTitle"];
    [aCoder encodeInt:numUnreadPosts forKey:@"numUnreadPosts"];
    [aCoder encodeInt:threadRating forKey:@"threadRating"];
    [aCoder encodeInt:totalReplies forKey:@"totalReplies"];
    [aCoder encodeBool:alreadyRead forKey:@"alreadyRead"];
    [aCoder encodeInt:category forKey:@"category"];
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *tid = [aDecoder decodeObjectForKey:@"threadID"];
    NSString *tt =  [aDecoder decodeObjectForKey:@"threadTitle"];
    int num = [aDecoder decodeIntForKey:@"numUnreadPosts"];
    int rate = [aDecoder decodeIntForKey:@"threadRating"];
    int rep = [aDecoder decodeIntForKey:@"totalReplies"];
    BOOL already = [aDecoder decodeBoolForKey:@"alreadyRead"];
    int cat = [aDecoder decodeIntForKey:@"category"];
    
    self.threadID = tid;
    self.threadTitle = tt;
    self.numUnreadPosts = num;
    self.threadRating = rate;
    self.totalReplies = rep;
    self.alreadyRead = already;
    self.category = cat;
    
    return self;
}

-(NSString *)getThreadTagHTML
{
    if([threadIcon isEqualToString:@""]) {
        return @"";
    }
    return [NSString stringWithFormat:@"<html><head><style type='text/css'>html {margin:0px;padding0px;} body{margin:0px;padding0px;}</style></head><body><img width='36' height='9' src='%@'/></body></html>", threadIcon];
}

@end
