//
//  YosposhCommand.h
//  Awful
//
//  Created by me on 8/10/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AwfulYOSPOSFakeShell.h"

@interface YosposhCommand : NSObject
-(id) initWithArgs:(NSArray*)args shell:(AwfulYOSPOSFakeShell*)shell;
-(void) done;

@property (nonatomic,strong,readonly) AwfulYOSPOSFakeShell* shell;
@end
