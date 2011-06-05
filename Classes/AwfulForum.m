//
//  AwfulForum.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForum.h"


@implementation AwfulForum

@synthesize forumName, forumID;

-(id)initWithName : (NSString *)name forumid : (NSString *)forumid
{
    forumName = [name retain];
    forumID = [forumid retain];
    return self;
}

-(void)dealloc
{
    [forumName release];
    [forumID release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:forumName forKey:@"name"];
    [coder encodeObject:forumID forKey:@"forum_id"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    forumName = [[coder decodeObjectForKey:@"name"] retain];
    forumID = [[coder decodeObjectForKey:@"forum_id"] retain];
    return self;
}

@end
