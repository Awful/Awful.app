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
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    [self.textLabel removeFromSuperview];
    [self.detailTextLabel removeFromSuperview];
    
    int i = 0;
    self.backgroundColor = [UIColor colorWithWhite:.88 alpha:1];
    for(UIView* v in _emoteViews) {
        v.frame = CGRectMake((101*i), 1, 100, 44);
        [self addSubview:v];
        //v.foX = v.foX + (150*i);
        i++;
    }
}

-(UIView*) setupSubviewForEmoticon:(AwfulEmote*)emote {
    UIView *v = [UIView new];

    UILabel *l = [UILabel new];
    l.frame = CGRectMake(0,27,100,17);
    l.text = emote.code;
    l.textAlignment = UITextAlignmentCenter;
    l.adjustsFontSizeToFitWidth = YES;
    
    
    [v addSubview:l];
    
    UIImageView *iv = [UIImageView new];
    iv.backgroundColor = [UIColor whiteColor];
    
    
    if (emote.imageData != nil) {
        iv.image = [UIImage imageWithData:emote.imageData];
    }
    
    iv.frame = CGRectMake(0,1,100,26);
    iv.contentMode = UIViewContentModeCenter;
    
    [v addSubview:iv];
    //v.layer.borderWidth = 1.0f;
    //v.layer.borderColor = [[UIColor colorWithWhite:.88 alpha:1] CGColor];
    
    return v;
}

@end
