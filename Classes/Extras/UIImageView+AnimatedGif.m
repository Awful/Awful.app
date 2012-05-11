//
//  UIImageView+Lazy.m
//  Awful
//
//  Created by me on 4/16/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "UIImageView+AnimatedGif.h"
#import "AwfulCachedImage.h"
#import "AnimatedGif.h"

@implementation UIImageView (AnimatedGif)

-(void) setAwfulImage:(AwfulCachedImage*)i {
    self.image = nil;
    if ([i.urlString rangeOfString:@".gif"].location != NSNotFound) {
        self.animatedGifImage = i.imageData;
    }
    else {
        self.image = [UIImage imageWithData:i.imageData];
    }
}

-(AwfulCachedImage*) awfulImage {
    return nil;
}

-(void) setAnimatedGifImage:(NSData *)imageData {
    AnimatedGif *gif = [AnimatedGif new];
    [gif decodeGIF:imageData];
    gif.imageView = self;
    [gif getAnimation];
}

-(AwfulCachedImage*) animatedGifImage {
    return nil;
}

@end
