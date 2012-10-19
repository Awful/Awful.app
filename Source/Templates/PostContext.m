//
//  PostContext.m
//  Awful
//
//  Created by Nolan Waite on 12-04-12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "PostContext.h"
#import "AwfulPost.h"
#import "AwfulSettings.h"
#import "TFHpple.h"
#import "TFHppleElement.h"

@implementation PostContext

static NSString *AwfulifiedPostBody(NSString *body);

- (id)initWithPost:(AwfulPost *)post
{
    self = [super init];
    if (self)
    {
        _postID = post.postID;
        _isOP = post.isOP;
        _avatarURL = [[AwfulSettings settings] showAvatars] ? [post.avatarURL absoluteString] : nil;
        _isMod = post.posterType == AwfulUserTypeMod;
        _isAdmin = post.posterType == AwfulUserTypeAdmin;
        _posterName = post.posterName;
        _postDate = post.postDate;
        _regDate = post.regDate;
        _altCSSClass = post.altCSSClass;
        _postBody = AwfulifiedPostBody(post.postBody);
    }
    return self;
}

static NSString *AwfulifiedPostBody(NSString *body)
{
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableString *awfulified = [body mutableCopy];
    
    // Replace images with links if so desired.
    if (![[AwfulSettings settings] showImages]) {
        NSArray *objects = [base search:@"//img"];
        NSArray *object_strs = [base rawSearch:@"//img"];
        for(NSUInteger i = 0; i < [objects count]; i++) {
            TFHppleElement *el = [objects objectAtIndex:i];
            NSString *src = [el objectForKey:@"src"];
            NSString *reformed = [NSString stringWithFormat:@"<a href='%@'>IMG LINK</a>", src];
            [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                        withString:reformed
                                           options:0
                                             range:NSMakeRange(0, awfulified.length)];
        }
    }
    
    NSArray *objects = [base search:@"//iframe"];
    NSArray *object_strs = [base rawSearch:@"//iframe"];
    for(NSUInteger i = 0; i < [objects count]; i++) {
        TFHppleElement *el = [objects objectAtIndex:i];
        NSString *str = [object_strs objectAtIndex:i];
        
        NSString *size = @"";
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            size = @"width='496' height='279'";
        }
        
        NSString *src = [el objectForKey:@"src"];
        NSString *reformed = [NSString stringWithFormat:@"<iframe type='text/html' src='%@&showinfo=0' frameborder='0' %@ allowfullscreen></iframe>", src, size];
        [awfulified replaceOccurrencesOfString:str
                                    withString:reformed
                                       options:0
                                         range:NSMakeRange(0, awfulified.length)];
    }
    
    // TODO what's going on here?
    [awfulified replaceOccurrencesOfString:@"&#13;"
                                withString:@""
                                   options:0
                                     range:NSMakeRange(0, awfulified.length)];
    
    return awfulified;
}

@synthesize postID = _postID;
@synthesize isOP = _isOP;
@synthesize avatarURL = _avatarURL;
@synthesize isMod = _isMod;
@synthesize isAdmin = _isAdmin;
@synthesize posterName = _posterName;
@synthesize postDate = _postDate;
@synthesize regDate = _regDate;
@synthesize altCSSClass = _altCSSClass;
@synthesize postBody = _postBody;

@end
