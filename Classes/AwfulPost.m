//
//  AwfulPost.m
//  Awful
//
//  Created by Sean Berry on 7/31/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPost.h"

@implementation PageManager

@synthesize current, total;

-(id)init
{
    current = -1;
    total = -1;
    return self;
}

@end


@implementation AwfulPost

@synthesize postID, postDate, userName;
@synthesize avatar, content, edited, userType;
@synthesize byOP, rawContent, newest, seenLink;
@synthesize postBody, isMod, isAdmin, isLoaded;
@synthesize canEdit;

-(id)init
{
    postID = nil;
    postDate = nil;
    userName = nil;
    avatar = nil;
    content = nil;
    edited = nil;
    userType = USER_TYPE_NORMAL;
    rawContent = nil;
    newest = NO;
    seenLink = nil;
    postBody = nil;
    isMod = NO;
    isAdmin = NO;
    isLoaded = NO;
    canEdit = NO;
    return self;
}

-(void)dealloc
{
    [postID release];
    [postDate release];
    [userName release];
    [avatar release];
    [content release];
    [edited release];
    [rawContent release];
    [seenLink release];
    [postBody release];
    [super dealloc];
}

@end

