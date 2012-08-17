//
//  AwfulHTTPClient+ThreadTags.h
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"

typedef void (^ThreadTagListResponseBlock)(NSMutableArray *threadTags);
typedef void (^ThreadTagCacheResponseBlock)();

@class AwfulThreadTag;

@interface AwfulHTTPClient (ThreadTags)
-(NSOperation *)threadTagListForForum:(AwfulForum*)forum
                         onCompletion:(ThreadTagListResponseBlock)ThreadTagListResponseBlock
                              onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)cacheThreadTag:(AwfulThreadTag*)threadTag
                 onCompletion:(ThreadTagCacheResponseBlock)threadTagCacheResponseBlock
                      onError:(AwfulErrorBlock)errorBlock;

@end
