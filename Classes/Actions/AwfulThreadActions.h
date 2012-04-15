//
//  AwfulThreadActions.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"

@class AwfulThread;

@interface AwfulThreadActions : AwfulActions

@property (readonly, strong) AwfulThread *thread;

-(id)initWithThread : (AwfulThread *)thread;

@end
