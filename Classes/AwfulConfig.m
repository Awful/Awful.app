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

+(BOOL)imagesInline
{
    NSNumber *im = [AwfulConfig getConfigObj:@"images_inline"];
    if(im == nil) {
        return YES;
    }
    return [im boolValue];
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

+(BOOL)isPortraitLock
{
    NSNumber *port = [AwfulConfig getConfigObj:@"lock_portrait"];
    if(port == nil) {
        return YES;
    }
    return [port boolValue];
}

+(BOOL)isLandscapeLock
{
    NSNumber *land = [AwfulConfig getConfigObj:@"lock_landscape"];
    if(land == nil) {
        return NO;
    }
    return [land boolValue];
}

+(BOOL)isColorSchemeBlack
{
    NSString *color = [AwfulConfig getConfigObj:@"color_scheme"];
    if(color == nil) {
        return YES;
    }
    return YES;
}

+(BOOL)allowRotation : (UIInterfaceOrientation)orient
{
    BOOL ill_allow_it = NO;
    
    if([AwfulConfig isPortraitLock]) {
        if(UIInterfaceOrientationIsPortrait(orient)) {
            ill_allow_it = YES;
        }
    } else if([AwfulConfig isLandscapeLock]) {
        if(!UIInterfaceOrientationIsPortrait(orient)) {
            ill_allow_it = YES;
        }
    } else {
        ill_allow_it = YES;
    }
    
    return ill_allow_it;
}

+(UIFont *)getCellTitleFont
{
    return [UIFont fontWithName:@"Helvetica" size:14.0];
}

+(UIFont *)getCellUnreadFont
{
    return [UIFont fontWithName:@"Helvetica-Bold" size:17.0];
}

+(UIFont *)getCellPagesFont
{
    return [UIFont fontWithName:@"Helvetica" size:10.0];

}

@end