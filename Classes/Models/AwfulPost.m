//
//  AwfulPost.m
//  Awful
//
//  Created by Sean Berry on 7/31/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPost.h"

@implementation AwfulPost

@synthesize postID, postDate, posterName;
@synthesize posterType, avatarURL, editedStr;
@synthesize formattedHTML, rawContent, markSeenLink;
@synthesize isOP, canEdit;

-(id)init
{
    if((self=[super init])) {
        self.posterType = AwfulUserTypeNormal;
        self.isOP = NO;
        self.canEdit = NO;
    }
    return self;
}


@end

