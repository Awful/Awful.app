//
//  AwfulHTTPClient+Emoticons.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//


typedef void (^EmoticonListResponseBlock)(NSMutableArray *emoticons);
typedef void (^EmoticonCacheResponseBlock)();
@class AwfulEmote;
@interface AwfulHTTPClient (Emoticons)
-(NSOperation *)emoticonListOnCompletion:(EmoticonListResponseBlock)EmoticonListResponseBlock 
                                 onError:(AwfulErrorBlock)errorBlock;

-(NSOperation *)cacheEmoticon:(AwfulEmote*)emote 
                       onCompletion:(EmoticonCacheResponseBlock)EmoticonCacheResponseBlock 
                            onError:(AwfulErrorBlock)errorBlock;
@end
