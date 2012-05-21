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

@interface CloserFormRequest : ASIFormDataRequest

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) AwfulPost *post;

@end

@interface AwfulReplyRequest : ASIHTTPRequest

@property (nonatomic, strong) NSString *reply;
@property (nonatomic, strong) AwfulThread *thread;

-(id)initWithReply : (NSString *)aReply forThread : (AwfulThread *)aThread;

@end