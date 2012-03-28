//
//  ButtonSegmentedControl.m
//  Awful
//
//  Created by Sean Berry on 3/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ButtonSegmentedControl.h"
#import "AwfulPage.h"

@implementation ButtonSegmentedControl

@synthesize target = _target;
@synthesize action = _action;

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(self.selectedSegmentIndex != NSNotFound) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:self];
        #pragma clang diagnostic pop
        
    }
    [super touchesEnded:touches withEvent:event];
}

@end
