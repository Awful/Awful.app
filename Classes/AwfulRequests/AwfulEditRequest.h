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

@interface AwfulEditRequest : ASIHTTPRequest

@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) NSString *text;

-(id)initWithAwfulPost : (AwfulPost *)aPost withText : (NSString *)post_text;

@end


@interface AwfulEditContentRequest : ASIHTTPRequest

@property (nonatomic, strong) AwfulPost *post;

-(id)initWithAwfulPost : (AwfulPost *)aPost;


@end
