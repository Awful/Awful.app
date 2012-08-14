//
//  AwfulAnimatedGifActivityIndicatorView.h
//  Awful
//
//  Created by me on 7/19/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class FVGifAnimation;

@interface AwfulAnimatedGifActivityIndicatorView : UIActivityIndicatorView
@property (readonly) FVGifAnimation* animatedGif;
@property (nonatomic,readwrite) NSString* imagePath;


-(id) initWithImagePath:(NSString*)imagePath;
@end
