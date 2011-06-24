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

@interface CloserFormRequest : ASIFormDataRequest {
    
}

@end

@interface AwfulReplyRequest : ASIHTTPRequest {
    NSString *_reply;
    AwfulThread *_thread;
}

@property (nonatomic, retain) NSString *reply;
@property (nonatomic, retain) AwfulThread *thread;

-(id)initWithReply : (NSString *)reply forThread : (AwfulThread *)thread;

@end
