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
#import "UIImageView+AnimatedGif.h"

@implementation AwfulTableViewCellEmoticonMultiple
@synthesize showCodes = _showCodes;

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
        
        for (UIView* sub in v.subviews) {
            if (sub.tag == 1) { //label
                sub.hidden = !self.showCodes;
            }
            else { //image
                sub.frame = self.showCodes? CGRectMake(0,1,100,26) : CGRectMake(0,1,100,42) ;
            }
        }
        
        //v.foX = v.foX + (150*i);
        i++;
    }
}

-(UIView*) setupSubviewForEmoticon:(AwfulEmote*)emote {
    UIView *v = [UIView new];

    UILabel *l = [UILabel new];
    l.frame = CGRectMake(0,26,100,18);
    l.text = emote.code;
    l.textAlignment = UITextAlignmentCenter;
    l.adjustsFontSizeToFitWidth = YES;
    l.tag = 1;
    
    [v addSubview:l];
    
    UIImageView *iv = [UIImageView new];
    iv.tag = 2;
    iv.backgroundColor = [UIColor whiteColor];
    
    
    if (emote.imageData != nil) {
        iv.awfulImage = emote;
    }
    
    iv.frame = self.showCodes? CGRectMake(0,1,100,26) : CGRectMake(0,1,100,42) ;
    iv.contentMode = UIViewContentModeCenter;
    
    [v addSubview:iv];
    //v.layer.borderWidth = 1.0f;
    //v.layer.borderColor = [[UIColor colorWithWhite:.88 alpha:1] CGColor];
    
    return v;
}

@end
