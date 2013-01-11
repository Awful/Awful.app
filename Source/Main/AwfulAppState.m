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

@end