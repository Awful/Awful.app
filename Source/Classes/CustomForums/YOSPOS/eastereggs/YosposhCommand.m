//
//  YosposhCommand.m
//  Awful
//
//  Created by me on 8/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "YosposhCommand.h"

@implementation YosposhCommand
-(id) initWithArgs:(NSArray *)args shell:(AwfulYOSPOSFakeShell *)shell {
    self = [super init];
    _shell = shell;
    return self;
}

-(void) done {
    self.shell.isExecuting = NO;
}

@end
