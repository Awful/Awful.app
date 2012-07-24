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
#import "FVGifAnimation.h"
#import "AwfulHTTPClient+Emoticons.h"

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
    //[self.textLabel removeFromSuperview];
    //[self.detailTextLabel removeFromSuperview];
    self.textLabel.text = @"x";
    int i = 0;
    self.backgroundColor = [UIColor colorWithWhite:.88 alpha:1];
    for(UIView* v in _emoteViews) {
        v.frame = CGRectMake((126*i), 0, 125, self.fsH);
        [self addSubview:v];
        
        for (UIView* sub in v.subviews) {
            if (sub.tag == 1) { //label
                sub.hidden = !self.showCodes;
                sub.frame = CGRectMake(0,35,125,self.fsH-36);
            }
            else { //image
                sub.frame = self.showCodes? CGRectMake(0,0,125,35) : CGRectMake(0,0,125,v.fsH) ;
            }
        }
        
        //v.foX = v.foX + (150*i);
        i++;
    }
}

-(UIView*) setupSubviewForEmoticon:(AwfulEmote*)emote {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 125, self.fsH)];

    UILabel *l = [UILabel new];
    l.text = emote.code;
    l.textAlignment = UITextAlignmentCenter;
    l.adjustsFontSizeToFitWidth = YES;
    l.font = [UIFont systemFontOfSize:12];
    l.textColor = [UIColor darkGrayColor];
    l.tag = 1;
    
    [v addSubview:l];
    
    UIImageView *iv = [UIImageView new];
    iv.tag = 2;
    
    //NSString* path = [[NSBundle mainBundle] pathForResource:emote.filename ofType:nil];
    //FVGifAnimation* animatedGif = [[FVGifAnimation alloc] initWithData:
    //               [NSData dataWithContentsOfFile:path]
    //                ];
    
    //[animatedGif setAnimationToImageView:self.imageView];
    
    iv.image = [UIImage imageNamed:emote.filename.lastPathComponent];
    
     if (!iv.image) {
         //not in the bundle, check to see if it's a local path
         NSURL *url = [NSURL URLWithString:emote.filename];
         
         if (url.isFileURL) {
             iv.image = [UIImage imageWithContentsOfFile:url.path];
             
         }
         else {
            NSLog(@"would load %@",emote.filename); 
             [[AwfulHTTPClient sharedClient] cacheEmoticon:emote 
                                                    onCompletion:^(NSMutableArray *messages) {
                                                        //[self finishedRefreshing];
                                                    }
                                                         onError:^(NSError *error) {
                                                             //[self finishedRefreshing];
                                                             [ApplicationDelegate requestFailed:error];
                                                         }];

            }
     
    
    /*
     //NSLog(@"loading emote %@", emote.code);
     
     
      */
     }   
    
    
    
    
    iv.frame = self.showCodes? CGRectMake(0,0,100,32) : CGRectMake(0,0,100,42) ;
    iv.contentMode = UIViewContentModeCenter;
    iv.backgroundColor = [UIColor whiteColor];
    [v addSubview:iv];
    
    [self.imageView startAnimating];
    if (iv.contentScaleFactor == 2) {
        l.text = [l.text stringByAppendingString:@"***"];
    }
    //v.layer.borderWidth = 1.0f;
    //v.layer.borderColor = [[UIColor colorWithWhite:.88 alpha:1] CGColor];
    
    return v;
}

@end
