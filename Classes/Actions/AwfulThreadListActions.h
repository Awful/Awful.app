//
//  AwfulThreadListActions.h
//  Awful
//
//  Created by Regular Berry on 6/24/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"

@class AwfulThread;

@interface AwfulThreadListActions : AwfulActions {
    AwfulThread *_thread;
}

@property (nonatomic, strong) AwfulThread *thread;

-(id)initWithAwfulThread : (AwfulThread *)thread;

@end