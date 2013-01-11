//
//  AwfulHTTPClient+Emoticons.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient+Emoticons.h"
#import "AwfulModels.h"
#import "AwfulParsing+Emoticons.h"
#import "AwfulDataStack.h"
#import "NSFileManager+UserDirectories.h"

@implementation AwfulHTTPClient (Emoticons)
-(NSOperation *)emoticonListAndThen:(void (^)(NSError *))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSString *path = [NSString stringWithFormat:@"misc.php?action=showsmilies"];
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   NSData *responseData = (NSData *)response;
                                                                   EmoticonParsedInfo *parsedInfo = [[EmoticonParsedInfo alloc] initWithHTMLData:responseData];
                                                                   NSLog(@"parsedinfo%@",parsedInfo);
                                                                   //NSArray *msgs = [AwfulEmote parseEmoticonsWithData:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //EmoticonListResponseBlock(msgs);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   //errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

-(NSOperation *)cacheEmoticon:(AwfulEmoticon *)emoticon andThen:(void (^)(NSError *))callback
{
    //NetworkLogInfo(@"%@", THIS_METHOD);
    NSMutableURLRequest *urlRequest = [self requestWithMethod:@"GET" path:emoticon.urlString parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(AFHTTPRequestOperation *operation, id response) {
                                                                   //NetworkLogInfo(@"completed %@", THIS_METHOD);
                                                                   //NSData *responseData = (NSData *)response;
                                                                   //[AwfulEmote cacheEmoticon:emote data:responseData];
                                                                   //[ApplicationDelegate saveContext];
                                                                   //EmoticonListResponseBlock(void);
                                                               } 
                                                               failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                   //NetworkLogInfo(@"erred %@", THIS_METHOD);
                                                                   //errorBlock(error);
                                                               }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}


- (void)downloadUncachedEmoticons
{
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:[AwfulEmoticon entityName]];
    req.predicate = [NSPredicate predicateWithFormat:@"cachedPath == nil"];
    
    
    NSArray *tagsToDownload = [[[AwfulDataStack sharedDataStack] context]
                               executeFetchRequest:req
                               error:nil];
    
    NSMutableArray *batchOfOperations = [NSMutableArray new];
    for (AwfulEmoticon* downloadMe in tagsToDownload) {
        //self.downloadingEmoticons = NO;
        NSURLRequest *request = [self requestWithMethod:@"GET" path:downloadMe.urlString parameters:nil];
        AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                                   success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                       NSData *data = (NSData*)responseObject;
                                                                       UIImage *img = [UIImage imageWithData:data];
                                                                       downloadMe.widthValue = img.size.width;
                                                                       downloadMe.heightValue = img.size.height;
                                                                       NSString *path = [[[self cacheFolder] URLByAppendingPathComponent:downloadMe.urlString.lastPathComponent] path];
                                                                       
                                                                       [[NSFileManager defaultManager] createFileAtPath:path
                                                                         contents:data attributes:nil];
                                                                       downloadMe.cachedPath = path;
                                                                       
                                                                   } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                       //code
                                                                   }];
        //NSURL *outURL = [[self cacheFolder] URLByAppendingPathComponent:downloadMe.urlString.lastPathComponent];
        //op.outputStream = [NSOutputStream outputStreamWithURL:outURL append:NO];
        //downloadMe.cachedPath = outURL.filePathURL.path;
        [batchOfOperations addObject:op];
    }
    
    [self ensureCacheFolder];
    [self enqueueBatchOfHTTPRequestOperations:batchOfOperations
                                progressBlock:nil
                              completionBlock:^(NSArray *operations)
     {
         //self.downloadingEmoticons = NO;
         NSMutableArray *newlyCachedEmoticons = [NSMutableArray new];
         for (AFHTTPRequestOperation *op in operations) {
             if ([op hasAcceptableStatusCode]) {
                 [newlyCachedEmoticons addObject:[[op.request URL] lastPathComponent]];
             }
         }
         if ([newlyCachedEmoticons count] == 0) return;
         
         [[AwfulDataStack sharedDataStack] save];
         //[[NSNotificationCenter defaultCenter] postNotificationName:AwfulNewThreadTagsAvailableNotification
         //                                                    object:newlyAvailableTagNames];
     }];
}

- (NSURL *)cacheFolder
{
    NSURL *caches = [[NSFileManager defaultManager] cachesDirectory];
    return [caches URLByAppendingPathComponent:@"Emoticons"];
}

- (void)ensureCacheFolder
{
    NSError *error;
    BOOL ok = [[NSFileManager defaultManager] createDirectoryAtURL:[self cacheFolder] withIntermediateDirectories:YES attributes:nil error:&error];
    if (!ok) {
        NSLog(@"error creating thread tag cache folder %@: %@", [self cacheFolder], error);
    }
}
@end
