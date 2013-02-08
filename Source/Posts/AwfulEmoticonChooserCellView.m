//
//  AwfulEmoticonChooserCellView.m
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoticonChooserCellView.h"
#import "FVGifAnimation.h"

@interface AwfulEmoticonChooserCellView ()
@property (nonatomic) FVGifAnimation* animator;
@end

@implementation AwfulEmoticonChooserCellView
@synthesize textLabel = _textLabel;
@synthesize imageView = _imageView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        [self addSubview:self.imageView];
        [self addSubview:self.textLabel];
    }
    return self;
}

- (void)setEmoticon:(AwfulEmoticon *)emoticon {
    _emoticon = emoticon;
    self.textLabel.text = emoticon.code;
    self.imageView.animationImages = nil;
    
    if (emoticon.cachedPath != nil) {
        self.imageView.image = [UIImage imageWithContentsOfFile:emoticon.cachedPath];
        if ([emoticon.cachedPath hasSuffix:@".gif"]) {
            NSData *gifData = [NSData dataWithContentsOfFile:emoticon.cachedPath];
            if ([FVGifAnimation canAnimateImageData:gifData]) {
                self.animator = [[FVGifAnimation alloc] initWithData:gifData];
                [self.animator setAnimationToImageView:self.imageView];
                [self.imageView startAnimating];
            }
        }
    }
    
}

-(void) layoutSubviews {
    
    if (!self.imageView.image) {
        self.imageView.hidden = YES;
        self.textLabel.frame = self.bounds;
    }
    else {
        self.imageView.hidden = NO;
        self.imageView.frame = CGRectMake(0,
                                          0,
                                          self.frame.size.width,
                                          self.frame.size.height-15);
        
        self.textLabel.frame = CGRectMake(0,
                                          self.frame.size.height-15,
                                          self.frame.size.width,
                                          15);
    }
}

-(UILabel*) textLabel {
    if (_textLabel) return _textLabel;
    
    _textLabel = [UILabel new];
    _textLabel.textAlignment = UITextAlignmentCenter;
    _textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _textLabel.font = [UIFont systemFontOfSize:10];
    _textLabel.backgroundColor = [UIColor whiteColor];
    return _textLabel;
}

-(UIImageView*) imageView {
    if(_imageView) return _imageView;
    
    _imageView = [UIImageView new];
    _imageView.contentMode = UIViewContentModeCenter;
    _imageView.backgroundColor = [UIColor whiteColor];
    return _imageView;
}


@end
