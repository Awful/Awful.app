//
//  AwfulThreadActions.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"

@class AwfulPage;

@interface AwfulThreadActions : AwfulActions

@property (nonatomic, strong) AwfulPage *page;

-(id)initWithAwfulPage : (AwfulPage *)aPage;

@end
