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
@class AwfulPostBoxController;

@interface AwfulEditRequest : ASIHTTPRequest {
    AwfulPost *_post;
    NSString *_text;
}

-(id)initWithAwfulPost : (AwfulPost *)post withText : (NSString *)post_text;

@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) NSString *text;

@end


@interface AwfulEditContentRequest : ASIHTTPRequest {
    AwfulPost *_post;
}

-(id)initWithAwfulPost : (AwfulPost *)post;

@property (nonatomic, strong) AwfulPost *post;

@end
