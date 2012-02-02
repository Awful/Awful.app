//
//  AwfulQuoteRequest.h
//  Awful
//
//  Created by Sean Berry on 11/17/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"

@class AwfulPost;
@class AwfulPage;

@interface AwfulQuoteRequest : ASIHTTPRequest {
    AwfulPage *_page;
}

@property (nonatomic, strong) AwfulPage *page;

-(id)initWithPost : (AwfulPost *)post fromPage : (AwfulPage *)page;

@end
