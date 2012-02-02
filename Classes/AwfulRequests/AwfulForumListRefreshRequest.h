//
//  AwfulForumListRefreshRequest.h
//  Awful
//
//  Created by Regular Berry on 6/14/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"

@class AwfulForumsList;

@interface AwfulForumListRefreshRequest : ASIHTTPRequest {
    AwfulForumsList *_forumsList;
}

@property (nonatomic, strong) AwfulForumsList *forumsList;

-(id)initWithForumsList : (AwfulForumsList *)list;

@end
