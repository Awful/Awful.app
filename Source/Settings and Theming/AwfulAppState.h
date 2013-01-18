//
//  AwfulAppState.h
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulForum;

@interface AwfulAppState : NSObject

+ (AwfulAppState *)sharedAppState;

@property (nonatomic) NSUbiquitousKeyValueStore *awfulCloudStore;
@property (nonatomic) NSUInteger selectedTab;

//forums
@property (nonatomic,readonly) NSArray* favoriteForums;
@property (nonatomic,readonly) NSArray* expandedForums;
- (void)setForum:(AwfulForum*)forum isFavorite:(BOOL)isFavorite;
- (void)setForum:(AwfulForum*)forum isExpanded:(BOOL)isExpanded;
- (BOOL) isFavoriteForum:(AwfulForum*)forum;
- (BOOL) isExpandedForum:(AwfulForum*)forum;

//cookies
//@property (nonatomic,readonly) BOOL isLoggedIn;
@property (nonatomic) NSArray* forumCookieData;
-(void) syncForumCookies;
-(void) clearCloudCookies;

//scrolling
- (CGFloat) scrollOffsetPercentageForScreen:(NSURL*)awfulURL;
-(void) setScrollOffsetPercentage:(CGFloat)scrollOffset
                        forScreen:(NSURL*)awfulURL;

//nav stack
- (NSURL*)screenURLAtIndexPath:(NSIndexPath*)indexPath;
- (void)setScreenURL:(NSURL*)screenURL atIndexPath:(NSIndexPath*)indexPath;
- (NSIndexPath*)indexPathForViewController:(UIViewController*)viewController;

@end

// Keys for subscripting.
extern const struct AwfulStateKeys {
    __unsafe_unretained NSString *selectedTab;
    __unsafe_unretained NSString *navigationStack;
    __unsafe_unretained NSString *favoriteForums;
    __unsafe_unretained NSString *expandedForums;
    __unsafe_unretained NSString *cookieData;
} AwfulStateKeys;

static NSString* const kAwfulAppStateSelectedTabKey       = @"kAwfulAppStateSelectedTab";
static NSString* const kAwfulAppStateNavStackKey          = @"kAwfulAppStateNavStack";
static NSString* const kAwfulAppStateScrollOffsetsKey     = @"kAwfulAppStateScrollOffsetsKey";

static NSString* const kAwfulAppStateFavoriteForumsKey    = @"kAwfulAppStateFavoriteForums";
static NSString* const kAwfulAppStateExpandedForumsKey    = @"kAwfulAppStateExpandedForums";

static NSString* const kAwfulAppStateForumCookieDataKey   = @"kAwfulAppStateForumCookieData";


static NSString* const AwfulAppStateDidUpdateFavoriteForums   = @"AwfulAppStateDidUpdateFavoriteForums";
static NSString* const AwfulAppStateDidUpdateExpandedForums   = @"AwfulAppStateDidUpdateExpandedForums";