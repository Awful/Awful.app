//
//  AwfulPageRefreshRequest.h
//  Awful
//
//  Created by Sean Berry on 11/13/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "AwfulPage.h"
#import "AwfulTestPage.h"

@interface AwfulPageRefreshRequest : ASIHTTPRequest {
    AwfulPage *page;
}

@property (nonatomic, retain) AwfulPage *page;

-(id)initWithAwfulPage : (AwfulPage *)in_page;

@end

@interface AwfulTestPageRequest : ASIHTTPRequest {
    AwfulTestPage *_page;
}

@property (nonatomic, retain) AwfulTestPage *page;

-(id)initWithAwfulTestPage : (AwfulTestPage *)page;

@end