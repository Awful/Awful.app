//
//  AwfulReplyRequest.h
//  Awful
//
//  Created by Sean Berry on 11/16/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "AwfulThread.h"

@interface AwfulReplyRequest : ASIHTTPRequest {
    NSString *reply;
    AwfulThread *thread;
}

-(id)initWithReply : (NSString *)in_reply forThread : (AwfulThread *)in_thread;

@end
