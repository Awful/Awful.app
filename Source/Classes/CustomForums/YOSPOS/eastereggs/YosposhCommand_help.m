//
//  YosposhCommand-help.m
//  Awful
//
//  Created by me on 8/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "YosposhCommand_help.h"

@implementation YosposhCommand_help
-(id) initWithArgs:(NSArray *)args shell:(AwfulYOSPOSFakeShell *)shell {
    self = [super initWithArgs:args shell:shell];
    
    [shell outputLine:@"GNU yosposh, version 2.19(1)-dev (arm-apple-darwin12)"];
    [self done];
    
    return self;
}
@end
