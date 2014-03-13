//  HTMLNode+CachedSelector.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <HTMLReader/HTMLReader.h>

@interface HTMLNode (CachedSelector)

- (NSArray *)awful_nodesMatchingCachedSelector:(NSString *)selectorString;

- (HTMLElementNode *)awful_firstNodeMatchingCachedSelector:(NSString *)selectorString;


@end
