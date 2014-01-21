//
//  HTMLNode+CachedSelector.h
//  Awful
//
//  Created by Chris Williams on 1/21/14.
//  Copyright (c) 2014 Awful Contributors. All rights reserved.
//

#import <HTMLReader/HTMLReader.h>

@interface HTMLNode (CachedSelector)

- (NSArray *)awful_nodesMatchingCachedSelector:(NSString *)selectorString;

- (HTMLElementNode *)awful_firstNodeMatchingCachedSelector:(NSString *)selectorString;


@end
