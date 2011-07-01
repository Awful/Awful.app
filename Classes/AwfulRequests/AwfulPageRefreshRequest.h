//
//  AwfulPageRefreshRequest.h
//  Awful
//
//  Created by Sean Berry on 11/13/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "AwfulPage.h"

@interface AwfulPageRefreshRequest : ASIHTTPRequest {
    AwfulPage *_page;
}

@property (nonatomic, retain) AwfulPage *page;

-(id)initWithAwfulPage : (AwfulPage *)page;

@end