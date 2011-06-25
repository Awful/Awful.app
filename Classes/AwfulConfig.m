//
//  AwfulConfig.m
//  Awful
//
//  Created by Sean Berry on 1/1/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulConfig.h"


@implementation AwfulConfig


- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code.
}
*/

- (void)dealloc {
    [super dealloc];
}

+(id)getConfigObj : (NSString *)key
{
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    return [def objectForKey:key];
}

+(BOOL)showAvatars
{
    NSNumber *ava = [AwfulConfig getConfigObj:@"show_avatars"];
    if(ava == nil) {
        return YES;
    }
    return [ava boolValue];
}

+(float)bookmarksDelay
{
    NSString *delay = [AwfulConfig getConfigObj:@"bookmarks_delay"];
    if(delay == nil) {
        return 3;
    }
    return [delay floatValue];
}

+(int)numReadPostsAbove
{
    NSString *above = [AwfulConfig getConfigObj:@"posts_above"];
    if(above == nil) {
        return 1;
    }
    return [above intValue];
}

@end