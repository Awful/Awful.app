//
//  AwfulHTTPClient+Emoticons.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//


#import "AwfulHTTPClient.h"

@class AwfulEmoticon;

@interface AwfulHTTPClient (Emoticons)
-(NSOperation *)emoticonListAndThen:(void (^)(NSError *error))callback;

-(NSOperation *)cacheEmoticon:(AwfulEmoticon*)emoticon
                      andThen:(void (^)(NSError *error))callback;
@end
