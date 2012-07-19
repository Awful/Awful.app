//
//  AwfulAnimatedGifActivityIndicatorView.h
//  Awful
//
//  Created by me on 7/19/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AnimatedGif;

@interface AwfulAnimatedGifActivityIndicatorView : UIActivityIndicatorView
@property (readonly) AnimatedGif* animatedGif;
@property (nonatomic,readwrite) NSString* imagePath;


-(id) initWithImagePath:(NSString*)imagePath;
@end
