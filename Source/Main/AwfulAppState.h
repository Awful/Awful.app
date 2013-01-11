//
//  AwfulAppState.h
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* kAwfulAppStateSelectedTab = @"kAwfulAppStateSelectedTab";
static NSString* kAwfulAppStateNavStack = @"kAwfulAppStateNavStack";

static NSString* kAwfulAppStateNavForumsKey = @"kAwfulAppStateNavForumsKey";
static NSString* kAwfulAppStateNavFavoritesKey = @"kAwfulAppStateNavFavoritesKey";

static NSString* kAwfulAppStateScrollPositionKey = @"kAwfulAppStateScrollPositionKey";
static NSString* kAwfulAppStateScreenIDKey = @"kAwfulAppStateScrollScreenIDKey";


@interface AwfulAppState : NSObject
//+(void) threadScrollOffset;
+(NSUInteger) selectedTab;
+(void) setSelectedTab:(NSUInteger)index;
@end
