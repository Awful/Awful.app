//
//  AwfulHTTPClient+Emoticons.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//


typedef void (^EmoticonListResponseBlock)(NSMutableArray *emoticons);

@interface AwfulHTTPClient (Emoticons)
-(NSOperation *)emoticonListOnCompletion:(EmoticonListResponseBlock)EmoticonListResponseBlock 
                                 onError:(AwfulErrorBlock)errorBlock;
@end
