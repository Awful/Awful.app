//
//  AwfulHTTPClient+PrivateMessages.m
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+PrivateMessages.h"
#import "AwfulPM.h"

@implementation AwfulHTTPClient (PrivateMessages)

-(NSOperation *)privateMessageListOnCompletion:(PrivateMessagesListResponseBlock)PMListResponseBlock 
                                       onError:(AwfulErrorBlock)errorBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"private.php"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   NSMutableArray *msgs = [AwfulPM parsePMsWithData:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   PMListResponseBlock(msgs);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}
@end
