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
#import "AwfulAppDelegate.h"

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
{
    NSMutableDictionary *screens = [[self.awfulCloudStore objectForKey:kAwfulAppStateScrollOffsetsKey] mutableCopy];
    if (!screens) screens = [NSMutableDictionary new];
    
    screens[awfulURL.absoluteString] = [NSNumber numberWithFloat:scrollOffset];
    
    NSLog(@"Saving scroll%%: %f for %@", scrollOffset, awfulURL.absoluteString);
    
    [self.awfulCloudStore setObject:screens forKey:kAwfulAppStateScrollOffsetsKey];
    [self.awfulCloudStore synchronize];
}

- (CGFloat) scrollOffsetPercentageForScreen:(NSURL*)awfulURL {
    NSMutableDictionary *screens = [self.awfulCloudStore objectForKey:kAwfulAppStateScrollOffsetsKey];
    if (!screens) return 0;
    if (!screens[awfulURL.absoluteString]) return 0;
    return [screens[awfulURL.absoluteString] floatValue];
}

#pragma mark nav stack
- (NSURL*)screenURLAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *nav = [self.awfulCloudStore objectForKey:kAwfulAppStateNavStackKey];
    if (!nav) return nil;
    if (!nav[indexPath.section]) return nil;
    
    return [NSURL URLWithString:nav[indexPath.section][indexPath.row]];
}

- (void) setScreenURL:(NSURL *)screenURL atIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSLog(@"set %@ to %i.%i", screenURL.absoluteString, indexPath.section, indexPath.row);
        NSMutableArray *nav = [[self.awfulCloudStore objectForKey:kAwfulAppStateNavStackKey] mutableCopy];
        if (!nav) nav = [NSMutableArray new];
        
        while (nav.count <= (uint)indexPath.section) {
            [nav addObject:@""];
        }
        
        NSMutableArray *stack = nav[indexPath.section];
        if (!stack || [stack isKindOfClass:[NSString class]]) stack = [NSMutableArray new];
        else stack = [stack mutableCopy];
        
        if ((uint)indexPath.row < stack.count) {
            [stack removeObjectsInRange:NSMakeRange(indexPath.row, stack.count-indexPath.row)];
        }
        [stack addObject:screenURL.absoluteString];
        nav[indexPath.section] = stack;
        
        [self.awfulCloudStore setObject:nav forKey:kAwfulAppStateNavStackKey];
        [self.awfulCloudStore synchronize];
    });
}

- (NSIndexPath*)indexPathForViewController:(UIViewController *)viewController
{
    int row = [viewController.navigationController.viewControllers indexOfObject:viewController];
    
    UITabBarController *tabs = (UITabBarController*)[AwfulAppDelegate instance].tabBarController;
    int section = [tabs.viewControllers indexOfObject:viewController.navigationController];
    
    return [NSIndexPath indexPathForRow:row inSection:section];
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
