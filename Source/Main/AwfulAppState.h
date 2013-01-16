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

static NSString* kAwfulScreenStateScrollOffsetKey = @"kAwfulScreenStateScrollOffsetKey";
static NSString* kAwfulScreenStateScreenKey = @"kAwfulScreenStateScreenIDKey";


@interface AwfulAppState : NSObject
//+(void) threadScrollOffset;
+(NSUInteger) selectedTab;
+(void) setSelectedTab:(NSUInteger)index;

+(CGPoint) scrollOffsetAtIndexPath:(NSIndexPath*)indexPath;
+(void) setScrollOffset:(CGFloat)scrollOffset atIndexPath:(NSIndexPath*)indexPath;

@end