//
//  AwfulHTTPClient+PrivateMessages.m
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulParsing+PrivateMessages.h"
#import "AwfulDataStack.h"

@implementation AwfulHTTPClient (PrivateMessages)

-(NSOperation *)privateMessageListAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"private.php"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    //urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id data)
                                  {
                                      dispatch_async(self.parseQueue, ^{
                                          NSArray *infos = [PrivateMessageParsedInfo messagesWithHTMLData:data];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              NSArray *pms = [AwfulPrivateMessage privateMessagesCreatedOrUpdatedWithParsedInfo:infos];
                                              [[AwfulDataStack sharedDataStack] save];
                                              if (callback) callback(nil, pms);
                                          });
                                      });
                                  } failure:^(id _, NSError *error) {
                                      if (callback) callback(error, nil);
                                  }];

    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)loadPrivateMessage:(AwfulPrivateMessage*)message
                           andThen:(void (^)(NSError *error, AwfulPrivateMessage *message))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"private.php?action=show&privatemessageid=%@", message.messageID];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   [PrivateMessageParsedInfo parsePM:message withData:responseData];
                                                                   callback(nil, message);
                                                               }
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   callback(error, nil);
                                                                   
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)sendPrivateMessage:(AwfulPrivateMessage*)draft
                           andThen:(void (^)(NSError *error, AwfulPrivateMessage* message))callback
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
