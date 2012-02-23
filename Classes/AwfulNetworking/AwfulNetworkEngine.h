//
//  AwfulNetworkEngine.h
//  Awful
//
//  Created by Sean Berry on 2/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "MKNetworkEngine.h"

@class AwfulForum;

@interface AwfulNetworkEngine : MKNetworkEngine

typedef void (^ThreadListResponseBlock)(NSMutableArray *threads);
-(void)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock;

@end
