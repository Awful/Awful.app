//
//  AwfulAppState.m
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAppState.h"

@interface AwfulAppState ()
+(NSUserDefaults*) awfulDefaults;
@end

@implementation AwfulAppState

+(NSUserDefaults*) awfulDefaults
{
    return [NSUserDefaults standardUserDefaults];
}
/*
 -(void)setThreadScrollOffset:(CGFloat)threadScrollOffset
 {
 [self.userDefaults setFloat:threadScrollOffset forKey:AwfulAppStateThreadPosition];
 }
 
 -(CGFloat) threadScrollOffset {
 return [self.userDefaults floatForKey:AwfulAppStateThreadPosition];
 }
 */

+(void)setSelectedTab:(NSUInteger)selectedTab
{
    [AwfulAppState.awfulDefaults setInteger:selectedTab forKey:kAwfulAppStateSelectedTab];
    [AwfulAppState.awfulDefaults synchronize];
}

+(NSUInteger) selectedTab {
    return [AwfulAppState.awfulDefaults integerForKey:kAwfulAppStateSelectedTab];
}

+(void) setScrollOffset:(CGFloat)scrollOffset atIndexPath:(NSIndexPath*)indexPath
{
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
}

+(CGPoint) scrollOffsetAtIndexPath:(NSIndexPath*)indexPath
{
    NSArray *array = [AwfulAppState.awfulDefaults arrayForKey:kAwfulAppStateNavStack];
    NSDictionary *screenState = array[indexPath.section][indexPath.row];
    
    
    NSLog(@"Reading scroll position:%f for %i.%i", [[screenState objectForKey:kAwfulScreenStateScrollOffsetKey] floatValue], indexPath.section, indexPath.row);
    return CGPointMake(0, [[screenState objectForKey:kAwfulScreenStateScrollOffsetKey] floatValue]);
}

@end
