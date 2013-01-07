//
//  AwfulHTTPClient+PrivateMessages.h
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
//#import "AwfulDraft.h"

typedef void (^PrivateMessagesListResponseBlock)(NSError* error, NSMutableArray *messages);

@interface AwfulHTTPClient (PrivateMessages)

-(NSOperation *)privateMessageListAndThen:(PrivateMessagesListResponseBlock)PMListResponseBlock;

//-(NSOperation *)sendPrivateMessage:(AwfulDraft*)draft onCompletion:(CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock;

//-(NSOperation *)loadPrivateMessage:(AwfulPM*)message
//                      onCompletion:(PrivateMessagesListResponseBlock)PMListResponseBlock
//                           onError:(AwfulErrorBlock)errorBlock;
@end
