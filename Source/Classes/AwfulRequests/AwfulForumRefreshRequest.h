//
//  AwfulForumRefreshRequest.h
//  Awful
//
//  Created by Sean Berry on 11/13/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "ASIHTTPRequest.h"
#import "AwfulThreadList.h"

@interface AwfulForumRefreshRequest : ASIHTTPRequest

@property (nonatomic, strong) AwfulThreadList *threadList;

-(id)initWithAwfulThreadList : (AwfulThreadList *)aThreadList;

@end
