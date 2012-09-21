//
//  AwfulThreadActions.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"

@class AwfulThread;
@class AwfulPage;

@interface AwfulThreadActions : AwfulActions

@property (readonly, strong, nonatomic) AwfulThread *thread;

-(id)initWithThread : (AwfulThread *)thread;
-(AwfulPage *)getPage;

@end
