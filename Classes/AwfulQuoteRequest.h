//
//  AwfulQuoteRequest.h
//  Awful
//
//  Created by Sean Berry on 11/17/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "AwfulPost.h"
#import "AwfulPage.h"

@interface AwfulQuoteRequest : ASIHTTPRequest {
    AwfulPage *page;
}

-(id)initWithPost : (AwfulPost *)post fromPage : (AwfulPage *)in_page;

@end
