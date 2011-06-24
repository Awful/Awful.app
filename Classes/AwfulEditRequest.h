//
//  AwfulEditRequest.h
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"

@class AwfulPost;
@class AwfulPage;

@interface AwfulEditRequest : ASIHTTPRequest {
    AwfulPost *_post;
    NSString *_text;
}

-(id)initWithAwfulPost : (AwfulPost *)post withText : (NSString *)post_text;

@property (nonatomic, retain) AwfulPost *post;
@property (nonatomic, retain) NSString *text;

@end


@interface AwfulEditContentRequest : ASIHTTPRequest {
    AwfulPage *_page;
    AwfulPost *_post;
}

-(id)initWithAwfulPage : (AwfulPage *)page forAwfulPost : (AwfulPost *)post;

@property (nonatomic, retain) AwfulPage *page;
@property (nonatomic, retain) AwfulPost *post;

@end
