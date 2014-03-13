//  HTMLNode+CachedSelector.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
