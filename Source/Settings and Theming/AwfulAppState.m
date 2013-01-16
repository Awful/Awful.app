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
-(void) setScrollOffset:(CGFloat)scrollOffset atIndexPath:(NSIndexPath*)indexPath
{
    //probably want to save the current width too?
    //an ipad scroll position will be much lower than the same point on a phone
    //plus orientation differences too
    /*
    NSMutableArray *array = [[AwfulAppState.awfulDefaults arrayForKey:kAwfulAppStateNavStack] mutableCopy];
    if (!array) array = [NSMutableArray new];
    
    NSMutableArray *stack;
    if (indexPath.section < (int)array.count)
        stack = [array[indexPath.section] mutableCopy];
    else stack = [NSMutableArray new];
    
    NSMutableDictionary *screenState;
    if (indexPath.row < (int)stack.count)
        screenState = [stack[indexPath.row] mutableCopy];
    else screenState = [NSMutableDictionary new];
    
    screenState[kAwfulScreenStateScrollOffsetKey] = [NSNumber numberWithFloat:scrollOffset];
    
    stack[indexPath.row] = screenState;
    array[indexPath.section] = stack;
    
    [AwfulAppState.awfulDefaults setObject:array forKey:kAwfulAppStateNavStack];
    
    NSLog(@"Saving scroll position:%f for %i.%i", scrollOffset, indexPath.section, indexPath.row);
    [AwfulAppState.awfulDefaults synchronize];
     */
}

- (CGPoint) scrollOffsetAtIndexPath:(NSIndexPath*)indexPath
{
    /*
    NSArray *array = [AwfulAppState.awfulDefaults arrayForKey:kAwfulAppStateNavStack];
    if (indexPath.section < (int)array.count) {
        if (indexPath.row < (int)[array[indexPath.section] count]) {
            NSDictionary *screenState = array[indexPath.section][indexPath.row];
            NSLog(@"Reading scroll position:%f for %i.%i", [[screenState objectForKey:kAwfulScreenStateScrollOffsetKey] floatValue], indexPath.section, indexPath.row);
            return CGPointMake(0, [[screenState objectForKey:kAwfulScreenStateScrollOffsetKey] floatValue]);
        }
    }
        */
    return CGPointZero;
    
    
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
