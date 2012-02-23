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

@implementation AwfulNetworkEngine

-(void)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock;
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
}

@end
