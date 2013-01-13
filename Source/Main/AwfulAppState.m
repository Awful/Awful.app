//
//  AwfulAppState.m
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAppState.h"
#import "AwfulModels.h"

@interface AwfulAppState ()
@property (nonatomic) NSUserDefaults *awfulDefaults;
@property (nonatomic) NSUbiquitousKeyValueStore *awfulCloudDefaults;
@end

@implementation AwfulAppState

+ (AwfulAppState *)sharedAppState
{
    static AwfulAppState *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

-(NSUserDefaults*) awfulDefaults
{
    if (_awfulDefaults) return _awfulDefaults;
    _awfulDefaults = [NSUserDefaults standardUserDefaults];
    return _awfulDefaults;
}

-(NSUbiquitousKeyValueStore*) awfulCloudDefaults {
    if(_awfulCloudDefaults) return _awfulCloudDefaults;
    _awfulCloudDefaults = [NSUbiquitousKeyValueStore new];
    return _awfulCloudDefaults;
}

#pragma mark Remembering selected tab
-(void)setSelectedTab:(NSUInteger)selectedTab
{
    [self.awfulDefaults setInteger:selectedTab forKey:kAwfulAppStateSelectedTab];
    [self.awfulDefaults synchronize];
    
    [self.awfulCloudDefaults setLongLong:selectedTab forKey:kAwfulAppStateSelectedTab];
}

-(NSUInteger) selectedTab {
    int test = [self.awfulDefaults integerForKey:kAwfulAppStateSelectedTab];
    return [self.awfulDefaults integerForKey:kAwfulAppStateSelectedTab];
}


#pragma mark Remember favorite forums
+(void) setForum:(AwfulForum*)forum isFavorite:(BOOL)isFavorite
{
    
    
}


#pragma mark Remember expanded forums


#pragma mark Remembering scroll position
+(void) setScrollOffset:(CGFloat)scrollOffset atIndexPath:(NSIndexPath*)indexPath
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

+(CGPoint) scrollOffsetAtIndexPath:(NSIndexPath*)indexPath
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

@end
