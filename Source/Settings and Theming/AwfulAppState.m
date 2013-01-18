//
//  AwfulAppState.m
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAppState.h"
#import "AwfulModels.h"
#import "AwfulForum.h"
#import "AwfulDataStack.h"
#import "NSManagedObject+Awful.h"

@interface AwfulAppState ()
@end

@implementation AwfulAppState
#pragma mark init
+ (AwfulAppState *)sharedAppState
{
    static AwfulAppState *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

-(NSUbiquitousKeyValueStore*) awfulCloudStore {
    if(_awfulCloudStore) return _awfulCloudStore;
    _awfulCloudStore = [NSUbiquitousKeyValueStore new];
    return _awfulCloudStore;
}

#pragma mark Remembering selected tab
-(void)setSelectedTab:(NSUInteger)selectedTab
{
    [self.awfulCloudStore setLongLong:selectedTab forKey:kAwfulAppStateSelectedTabKey];
    [self.awfulCloudStore synchronize];
}

-(NSUInteger) selectedTab {
    return [self.awfulCloudStore longLongForKey:kAwfulAppStateSelectedTabKey];
}

#pragma mark Remember favorite forums

- (NSArray*) favoriteForums {
    NSArray *array = [self.awfulCloudStore arrayForKey:kAwfulAppStateFavoriteForumsKey];
    if (!array) array = [NSArray new];
    return array;
}

- (BOOL) isFavoriteForum:(AwfulForum*)forum
{
    return [self.favoriteForums containsObject:forum.forumID];
}

- (void)setForum:(AwfulForum*)forum isFavorite:(BOOL)isFavorite
{
    NSMutableArray *faves = [self.favoriteForums mutableCopy];
    
    if (isFavorite) {
        [faves addObject:forum.forumID];
    }
    else {
        [faves removeObject:forum.forumID];
    }
    
    [self.awfulCloudStore setArray:faves forKey:kAwfulAppStateFavoriteForumsKey];
    [self.awfulCloudStore synchronize];
}


#pragma mark Remember expanded forums

- (NSArray*) expandedForums {
    NSArray *array = [self.awfulCloudStore objectForKey:kAwfulAppStateExpandedForumsKey];
    if (!array) array = [NSArray new];
    return array;
}
- (BOOL) isExpandedForum:(AwfulForum*)forum
{
    return [self.expandedForums containsObject:forum.forumID];
}

- (void)setForum:(AwfulForum*)forum isExpanded:(BOOL)isExpanded
{
    NSMutableArray *expanded = [self.expandedForums mutableCopy];
    
    if (isExpanded) {
        [expanded addObject:forum.forumID];
    }
    else {
        [expanded removeObject:forum.forumID];
    }
    
    [self.awfulCloudStore setObject:expanded forKey:kAwfulAppStateExpandedForumsKey];
    [self.awfulCloudStore synchronize];
}

#pragma mark scroll positions
-(void) setScrollOffsetPercentage:(CGFloat)scrollOffset
                        forScreen:(NSURL*)awfulURL
                      atIndexPath:(NSIndexPath*)indexPath
{
    //AppStateNavStack = Array, one item for each tab
    //each item is an array
    //each of those is a dictionary containing screen url, scroll offset, width
    
    
    NSMutableArray *array = [[self.awfulCloudStore arrayForKey:kAwfulAppStateNavStackKey] mutableCopy];
    if (!array) array = [NSMutableArray new];
    
    NSMutableArray *stack;
    if (indexPath.section < (int)array.count)
        stack = [array[indexPath.section] mutableCopy];
    else stack = [NSMutableArray new];
    
    NSMutableDictionary *screenState = [[self screenInfoForIndexPath:indexPath] mutableCopy];
    if (!screenState) screenState = [NSMutableDictionary new];
    
    screenState[kAwfulScreenStateScrollOffsetPctKey] = [NSNumber numberWithFloat:scrollOffset];
    //screenState[kAwfulScreenStateScreenKey] = awfulURL;
    
    stack[indexPath.row] = screenState;
    array[indexPath.section] = stack;
    
    [self.awfulCloudStore setObject:array forKey:kAwfulAppStateNavStackKey];
    
    NSLog(@"Saving scroll%%: %f for %i.%i", scrollOffset, indexPath.section, indexPath.row);
    [self.awfulCloudStore synchronize];
}


-(NSDictionary*) screenInfoForIndexPath:(NSIndexPath*)indexPath {
    NSArray *array = [self.awfulCloudStore objectForKey:kAwfulAppStateNavStackKey];
    if (!array) array = [NSMutableArray new];
    
    NSMutableArray *stack;
    if (indexPath.section < (int)array.count)
        stack = [array[indexPath.section] mutableCopy];
    else stack = [NSMutableArray new];
    
    NSMutableDictionary *screenState;
    if (indexPath.row < (int)stack.count)
        screenState = [stack[indexPath.row] mutableCopy];
    
    return screenState;
}


#pragma mark cookies
-(NSArray*) forumCookies
{
    NSData *encoded = [self.awfulCloudStore objectForKey:kAwfulAppStateForumCookieDataKey];
    if ([encoded isKindOfClass:[NSData class]]) {
        NSArray *cookies = [NSKeyedUnarchiver unarchiveObjectWithData:encoded];
        return cookies;
    }
    return nil;
}

-(void) syncForumCookies
{
    NSArray *cloudCookies = self.forumCookies;
    if(!cloudCookies) cloudCookies = [NSArray new];
    
    NSURL *sa = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *localCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:sa];
    
    NSArray *combined = [cloudCookies arrayByAddingObjectsFromArray:localCookies];
    
    NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:combined];
    [self.awfulCloudStore setObject:encoded forKey:kAwfulAppStateForumCookieDataKey];
    
    for(NSHTTPCookie *cookie in combined) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
    
    [self.awfulCloudStore synchronize];
}

-(void) clearCloudCookies {
    [self.awfulCloudStore removeObjectForKey:kAwfulAppStateForumCookieDataKey];
    [self.awfulCloudStore synchronize];
}

#pragma mark misc

- (id)objectForKeyedSubscript:(id)key
{
    return [self.awfulCloudStore objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id)key
{
    NSParameterAssert(key);
    [self.awfulCloudStore setObject:object forKey:key];
}

@end
