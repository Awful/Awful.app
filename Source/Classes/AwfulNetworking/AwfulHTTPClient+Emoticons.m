//
//  AwfulHTTPClient+Emoticons.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+Emoticons.h"
#import "AwfulEmote.h"

@implementation AwfulHTTPClient (Emoticons)
-(NSOperation *)emoticonListOnCompletion:(EmoticonListResponseBlock)EmoticonListResponseBlock 
                                 onError:(AwfulErrorBlock)errorBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"misc.php?action=showsmilies"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   NSArray *msgs = [AwfulEmote parseEmoticonsWithData:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   EmoticonListResponseBlock(msgs);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)cacheEmoticon:(AwfulEmote*)emote 
                       onCompletion:(EmoticonCacheResponseBlock)EmoticonCacheResponseBlock 
                            onError:(AwfulErrorBlock)errorBlock
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:emote.filename parameters:nil];
    urlRequest.timeoutInterval = NetworkTimeoutInterval;
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   [AwfulEmote cacheEmoticon:emote data:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //EmoticonListResponseBlock(void);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}
@end
