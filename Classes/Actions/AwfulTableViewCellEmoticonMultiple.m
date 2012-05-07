//
//  AwfulTableViewCellEmoticonMultiple.m
//  Awful
//
//  Created by me on 4/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "AwfulTableViewCellEmoticonMultiple.h"
#import "AwfulEmote.h"
//#import "AnimatedGif.h"

@implementation AwfulTableViewCellEmoticonMultiple

-(void) setContent:(NSArray*)emotes {
    for(UIView* v in _emoteViews) {
        [v removeFromSuperview];
    }
    
    _emoteViews = [NSMutableArray new];
    
    for(AwfulEmote* i in emotes) {
        UIView *v = [self setupSubviewForEmoticon:i];
        
        [self addSubview:v];
        [_emoteViews addObject:v];
    }
    
}

-(void) layoutSubviews {
    [super layoutSubviews];
    [self.textLabel removeFromSuperview];
    [self.detailTextLabel removeFromSuperview];
    
    int i = 0;
    //for(UIView* v in _emoteViews) {
    for(int j=0; j<5; j++) {
        UILabel *v = [UILabel new];
        v.text = [NSString stringWithFormat:@"%i",i];
        v.frame = CGRectMake((100*j), 1, 100, 42);
        [self addSubview:v];
        //v.foX = v.foX + (150*i);
        i++;
    }
}

-(UIView*) setupSubviewForEmoticon:(AwfulEmote*)emote {
    UIView *v = [UIView new];
    
    UILabel *l = [UILabel new];
    l.frame = CGRectMake(0,30,150,14);
    l.text = emote.code;
    l.textAlignment = UITextAlignmentCenter;
    
    [v addSubview:l];
    
    UIImageView *iv = [UIImageView new];
    
    
    if (emote.imageData != nil) {
        iv.image = [UIImage imageWithData:emote.imageData];
    }
    
    iv.frame = CGRectMake(1,1,150,30);
    iv.contentMode = UIViewContentModeCenter;
    
    [v addSubview:iv];
    v.layer.borderWidth = 1.0f;
    
    return v;
}

@end
