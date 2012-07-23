//
//  NSObject+Lazy.m
//  Awful
//
//  Created by me on 7/23/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSObject+Lazy.h"

@implementation NSObject (Lazy)
-(NSArray*)arrayWrapper {
    return [NSArray arrayWithObject:self];
}
@end
