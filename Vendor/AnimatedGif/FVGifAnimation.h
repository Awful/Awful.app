//
//  FVGifAnimation.h
//  FutaView
//
//  Created by flexfrank on 12/06/20.
//  Copyright (c) 2012年 flexfrank.net. All rights reserved.
//

@import UIKit;

@interface FVGifAnimation : NSObject{
    NSArray* images;
    double duration;
    NSInteger loops;
}
+ (BOOL)canAnimateImageData:(NSData*)data;
+ (BOOL)canAnimateImageURL:(NSURL*)url;
- (BOOL)canAnimate;
- (id)initWithData:(NSData*)data;
- (id)initWithURL:(NSURL*)url;
- (void)setAnimationToImageView:(UIImageView*)imageView;
@end