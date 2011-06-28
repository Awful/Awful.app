//
//  AwfulPost.m
//  Awful
//
//  Created by Sean Berry on 7/31/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPost.h"

@implementation AwfulPost

@synthesize postID = _postID;
@synthesize postDate = _postDate;
@synthesize authorName = _authorName;
@synthesize authorType = _authorType;
@synthesize avatarURL = _avatarURL;
@synthesize editedStr = _editedStr;
@synthesize formattedHTML = _formattedHTML;
@synthesize rawContent = _rawContent;
@synthesize markSeenLink = _markSeenLink;
@synthesize isOP = _isOP;
@synthesize canEdit = _canEdit;

-(id)init
{
    _authorType = AwfulUserTypeNormal;
    _isOP = NO;
    _canEdit = NO;
    return self;
}

-(void)dealloc
{
    [_postID release];
    [_postDate release];
    [_authorName release];
    [_avatarURL release];
    [_editedStr release];
    [_formattedHTML release];
    [_rawContent release];
    [_markSeenLink release];
    [super dealloc];
}

@end

