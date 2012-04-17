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

@interface AwfulPostActions : AwfulActions

@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) AwfulPage *page;
@property (nonatomic, strong) NSString *postContents;

-(id)initWithAwfulPost : (AwfulPost *)aPost page : (AwfulPage *)aPage;

@end
