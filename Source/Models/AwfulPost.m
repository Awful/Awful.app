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
@synthesize posterType, avatarURL, regDate, editedStr;
@synthesize rawContent, markSeenLink, seen;
@synthesize isOP, canEdit, altCSSClass, postBody;
@synthesize postIndex = _postIndex;

-(id)init
{
    if((self=[super init])) {
        self.posterType = AwfulUserTypeNormal;
        self.isOP = NO;
        self.canEdit = NO;
        self.seen = NO;
        self.postIndex = NSNotFound;
    }
    return self;
}

-(void)setPostIndex : (NSUInteger)postIndex
{
    if(_postIndex != postIndex) {
        _postIndex = postIndex;
        
        NSString *base = @"altcolor";
        if(self.seen) {
            base = @"seen";
        }
        
        int suffix = 1;
        if(postIndex % 2 == 0) {
            suffix = 2;
        }
        self.altCSSClass = [base stringByAppendingFormat:@"%d", suffix];
    }
}

@end

