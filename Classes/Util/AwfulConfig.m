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

+(AwfulDefaultLoadType)getDefaultLoadType
{
    NSString *type = [AwfulConfig getConfigObj:@"default_load"];
    if([type isEqualToString:@"none"]) {
        return AwfulDefaultLoadTypeNone;
    } else if([type isEqualToString:@"bookmarks"]) {
        return AwfulDefaultLoadTypeBookmarks;
    } else if([type isEqualToString:@"forumslist"]) {
        return AwfulDefaultLoadTypeForums;
    }
    return AwfulDefaultLoadTypeBookmarks;
}

+(NSString *)username {
    NSString *result = [AwfulConfig getConfigObj:@"username"];
    
    if (result == nil) {
        return [NSString stringWithString:@""];
    }
    
    return result;
}

+(NSString *)highlightOwnQuotes {
    NSNumber *result = [AwfulConfig getConfigObj:@"highlight_own_quotes"];
    
    // Return strings here because javascript doesn't understand boolean values
    // after they get serialized
    if (result == nil) {
        return [NSString stringWithString:@"true"];
    }
    
    return [result boolValue] ? [NSString stringWithString:@"true"] : [NSString stringWithString:@"false"];
}

+(NSString *)highlightOwnMentions {
    NSNumber *result = [AwfulConfig getConfigObj:@"highlight_own_mentions"];
    
    // Return strings here because javascript doesn't understand boolean values
    // after they get serialized
    if (result == nil) {
        return [NSString stringWithString:@"true"];
    }
    
    return [result boolValue] ? [NSString stringWithString:@"true"] : [NSString stringWithString:@"false"];
}

@end