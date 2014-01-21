//
//  HTMLNode+CachedSelector.m
//  Awful
//
//  Created by Chris Williams on 1/21/14.
//  Copyright (c) 2014 Awful Contributors. All rights reserved.
//

#import "HTMLNode+CachedSelector.h"


@interface HTMLSelector (CachedSelector)
@end

@implementation HTMLSelector (CachedSelector)

+ (HTMLSelector *)cachedSelectorForString:(NSString *)selectorString
{
	static NSMutableDictionary *selectorCache = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		selectorCache = [NSMutableDictionary new];
	});
	
	HTMLSelector *selector = selectorCache[selectorString];
	
	if (!selector) {
		selector = [HTMLSelector selectorForString:selectorString];
		selectorCache[selectorString] = selector;
	}
	
	return selector;
}

@end

@implementation HTMLNode (CachedSelector)

- (NSArray *)awful_nodesMatchingCachedSelector:(NSString *)selectorString
{
	return [self nodesMatchingParsedSelector:[HTMLSelector cachedSelectorForString:selectorString]];
}

- (HTMLElementNode *)awful_firstNodeMatchingCachedSelector:(NSString *)selectorString
{
	return [self firstNodeMatchingParsedSelector:[HTMLSelector cachedSelectorForString:selectorString]];
}

@end
