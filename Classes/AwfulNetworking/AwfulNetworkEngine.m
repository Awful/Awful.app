//
//  AwfulNetworkEngine.m
//  Awful
//
//  Created by Sean Berry on 2/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNetworkEngine.h"
#import "AwfulForum.h"
#import "TFHpple.h"
#import "AwfulParse.h"
#import "AwfulThread.h"
#import "AwfulPage.h"
#import "AwfulPageDataController.h"

@implementation AwfulNetworkEngine

-(MKNetworkOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock
{
    NSString *path = [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&pagenumber=%u", forum.forumID, pageNum];
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        NSData *responseData = [completedOperation responseData];
        NSMutableArray *threads = [AwfulParse parseThreadsFromForumData:responseData];
        threadListResponseBlock(threads);
        
    } onError:^(NSError *error) {
        
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}


-(MKNetworkOperation *)threadListForBookmarksAtPageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock
{
    NSString *path = [NSString stringWithFormat:@"bookmarkthreads.php?pagenumber=%u", pageNum];
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        NSData *responseData = [completedOperation responseData];
        NSMutableArray *threads = [AwfulParse parseThreadsFromForumData:responseData];
        threadListResponseBlock(threads);
        
    } onError:^(NSError *error) {
        
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}

-(MKNetworkOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(MKNKErrorBlock)errorBlock
{
    NSString *append = @"";
    switch(destinationType) {
        case AwfulPageDestinationTypeFirst:
            append = @"";
            break;
        case AwfulPageDestinationTypeLast:
            append = @"&goto=lastpost";
            break;
        case AwfulPageDestinationTypeNewpost:
            append = @"&goto=newpost";
            break;
        case AwfulPageDestinationTypeSpecific:
            append = [NSString stringWithFormat:@"&pagenumber=%d", pageNum];
            break;
        default:
            append = @"";
            break;
    }
    
    NSString *path = [[NSString alloc] initWithFormat:@"showthread.php?threadid=%@%@", thread.threadID, append];
    MKNetworkOperation *op = [self operationWithPath:path];
    
    [op onCompletion:^(MKNetworkOperation *completedOperation) {
        
        AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:[completedOperation responseData] pagePath:path];
        pageResponseBlock(data_controller);
        
    } onError:^(NSError *error) {
        
        errorBlock(error);
    }];
    
    [self enqueueOperation:op];
    return op;
}

@end
