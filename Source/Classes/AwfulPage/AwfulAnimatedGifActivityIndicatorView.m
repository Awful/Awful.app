//
//  AwfulAnimatedGifActivityIndicatorView.m
//  Awful
//
//  Created by me on 7/19/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAnimatedGifActivityIndicatorView.h"
#import "FVGifAnimation.h"

@interface AwfulAnimatedGifActivityIndicatorView ()
@property (readonly,strong) UIImageView* imageView;
@end


@implementation AwfulAnimatedGifActivityIndicatorView
@synthesize animatedGif = _animatedGif;
@synthesize imagePath = _imagePath;
@synthesize imageView = _imageView;

-(id) initWithImagePath:(NSString*)imagePath {
    self = [super init];
    
    _imageView = [[UIImageView alloc] initWithImage:
                  [UIImage imageNamed:[imagePath lastPathComponent]]
                  ];
    
    _animatedGif = [[FVGifAnimation alloc] initWithData:
                    [NSData dataWithContentsOfFile:imagePath ]
                    ];
    
    [self.animatedGif setAnimationToImageView:self.imageView];
    
    [self.imageView sizeToFit];

    self.frame = self.imageView.frame;
    self.color = [UIColor clearColor];
    [self addSubview:self.imageView];
    
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    
}

-(void) startAnimating {
    self.hidden = NO;
    [self.imageView startAnimating];
}

-(void) stopAnimating {
    self.hidden = YES;
    [self.imageView stopAnimating];
}

@end
