//
//  AwfulReplyRequest.h
//  Awful
//
//  Created by Sean Berry on 11/16/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"

@class AwfulThread;
@class AwfulPost;

@interface CloserFormRequest : ASIFormDataRequest {
    AwfulThread *_thread;
    AwfulPost *_post;
}

@property (nonatomic, retain) AwfulThread *thread;
@property (nonatomic, retain) AwfulPost *post;

@end

@interface AwfulReplyRequest : ASIHTTPRequest {
    NSString *_reply;
    AwfulThread *_thread;
}

@property (nonatomic, retain) NSString *reply;
@property (nonatomic, retain) AwfulThread *thread;

-(id)initWithReply : (NSString *)reply forThread : (AwfulThread *)thread;

@end