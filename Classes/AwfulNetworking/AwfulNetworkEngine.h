//
//  AwfulNetworkEngine.h
//  Awful
//
//  Created by Sean Berry on 2/22/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "MKNetworkEngine.h"
#import "AwfulPage.h"

@class AwfulForum;
@class AwfulThread;
@class AwfulPageDataController;

@interface AwfulNetworkEngine : MKNetworkEngine

typedef void (^ThreadListResponseBlock)(NSMutableArray *threads);
typedef void (^PageResponseBlock)(AwfulPageDataController *dataController);

-(MKNetworkOperation *)threadListForForum:(AwfulForum *)forum pageNum:(NSUInteger)pageNum onCompletion:(ThreadListResponseBlock)threadListResponseBlock onError:(MKNKErrorBlock) errorBlock;

-(MKNetworkOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(MKNKErrorBlock)errorBlock;

@end
