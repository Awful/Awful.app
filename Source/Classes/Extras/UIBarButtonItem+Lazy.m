//
//  UIBarButtonItem+Lazy.m
//  Awful
//
//  Created by me on 7/25/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "UIBarButtonItem+Lazy.h"

@implementation UIBarButtonItem (Lazy)
+(UIBarButtonItem*) flexibleSpace {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace) target:nil action:nil];
}
@end
