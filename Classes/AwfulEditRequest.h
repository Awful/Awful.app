//
//  AwfulEditRequest.h
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "AwfulPage.h"
#import "AwfulPost.h"

@interface AwfulEditRequest : ASIHTTPRequest {
    AwfulPost *post;
    NSString *text;
}

-(id)initWithAwfulPost : (AwfulPost *)in_post withText : (NSString *)post_text;

@end


@interface AwfulEditContentRequest : ASIHTTPRequest {
    AwfulPage *page;
    AwfulPost *post;
}

-(id)initWithAwfulPage : (AwfulPage *)in_page forAwfulPost : (AwfulPost *)in_post;

@end
