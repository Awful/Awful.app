//
//  UIImageView+Lazy.h
//  Awful
//
//  Created by me on 4/16/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulCachedImage;

@interface UIImageView (AnimatedGif)

@property (nonatomic,strong) AwfulCachedImage* awfulImage;
@property (nonatomic,strong) NSData* animatedGifImage;
@end
