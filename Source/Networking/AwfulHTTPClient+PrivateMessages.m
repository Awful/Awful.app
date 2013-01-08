//
//  AwfulHTTPClient+PrivateMessages.m
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulParsing+PrivateMessages.h"
//#import "AwfulDraft.h"

@implementation AwfulHTTPClient (PrivateMessages)

-(NSOperation *)privateMessageListAndThen:(PrivateMessagesListResponseBlock)PMListResponseBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"private.php"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    //urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   NSMutableArray *msgs = [PrivateMessageParsedInfo parsePMListWithData:responseData];
                                                                   
                                                                   NSError *error;
                                                                   PMListResponseBlock(error, msgs);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   PMListResponseBlock(error, nil);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}


-(NSOperation *)loadPrivateMessage:(AwfulPrivateMessage*)message
                           andThen:(PrivateMessagesListResponseBlock)PMListResponseBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"private.php?action=show&privatemessageid=%@", message.messageID];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   [PrivateMessageParsedInfo parsePM:message withData:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //PMListResponseBlock(msgs);
                                                               }
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)sendPrivateMessage:(AwfulPrivateMessage*)draft
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    //NSString *path = [NSString stringWithFormat:@"newreply.php?s=&action=newreply&threadid=%@", thread.threadID];
    //NSMutableDictionary *params = [msg dictionaryWithValuesForKeys:nil];
    NSLog(@"%@",draft.entity.attributesByName.allKeys);
    return nil;
    /*
    NSURLRequest *postRequest = [self requestWithMethod:@"POST" path:@"private.php" parameters:nil];
    
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:postRequest
                                                                    success:^(AFHTTPRequestOperation *operation, id response) {
                                                                        //if (completionBlock) completionBlock();
                                                                    } 
                                                                    failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                        //if (errorBlock) errorBlock(error);
                                                                    }
                                       ];
       
    [self enqueueHTTPRequestOperation:op];

    return (NSOperation *)op;
     */
}

@end
