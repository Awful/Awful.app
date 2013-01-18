//
//  AwfulHTTPClient+PrivateMessages.h
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "AwfulPrivateMessage.h"

@interface AwfulHTTPClient (PrivateMessages)

-(NSOperation *)privateMessageListAndThen:(void (^)(NSError *error, NSArray *messages))callback;

-(NSOperation *)sendPrivateMessage:(AwfulPrivateMessage*)draft
                           andThen:(void (^)(NSError *error, AwfulPrivateMessage *message))callback;

-(NSOperation *)loadPrivateMessage:(AwfulPrivateMessage*)message
                           andThen:(void (^)(NSError *error, AwfulPrivateMessage* message))callback;
@end
