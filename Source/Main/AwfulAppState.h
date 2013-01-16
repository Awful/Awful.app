//
//  AwfulAppState.h
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AwfulForum;

static NSString* kAwfulAppStateSelectedTab = @"kAwfulAppStateSelectedTab";
static NSString* kAwfulAppStateNavStack = @"kAwfulAppStateNavStack";

static NSString* kAwfulScreenStateScrollOffsetKey = @"kAwfulScreenStateScrollOffsetKey";
static NSString* kAwfulScreenStateScreenKey = @"kAwfulScreenStateScreenIDKey";

static NSString* kAwfulAppStateFavoriteForums = @"kAwfulAppStateFavoriteForums";
static NSString* kAwfulAppStateExpandedForums = @"kAwfulAppStateExpandedForums";

static NSString* kAwfulAppStateForumCookieData = @"kAwfulAppStateForumCookieData";


@interface AwfulAppState : NSObject

+ (AwfulAppState *)sharedAppState;

@property (nonatomic) NSUInteger selectedTab;


- (void)setForum:(AwfulForum*)forum isFavorite:(BOOL)isFavorite;
- (void)setForum:(AwfulForum*)forum isExpanded:(BOOL)isExpanded;

@property (nonatomic,readonly) NSArray* cloudFavorites;
@property (nonatomic,readonly) NSArray* cloudExpanded;


+(CGPoint) scrollOffsetAtIndexPath:(NSIndexPath*)indexPath;
+(void) setScrollOffset:(CGFloat)scrollOffset atIndexPath:(NSIndexPath*)indexPath;

@property (nonatomic,readonly) BOOL isLoggedIn;
@property (nonatomic) NSArray* forumCookieData;

@property (nonatomic,readonly) BOOL isiCloudSignedIn;
-(void) syncForumCookies;
-(void) clearCloudCookies;

- (void)syncCloudFavorites;
- (void)syncCloudExpanded;

//-(NSURL *) iCloudDataDirectory;

@end