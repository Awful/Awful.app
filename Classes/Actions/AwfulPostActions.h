//
//  AwfulPostActions.h
//  Awful
//
//  Created by Regular Berry on 6/24/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"

@class AwfulPost;
@class AwfulPage;

@interface AwfulPostActions : AwfulActions {
    AwfulPost *_post;
    AwfulPage *_page;
}

@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) AwfulPage *page;

-(id)initWithAwfulPost : (AwfulPost *)post page : (AwfulPage *)page;

@end
