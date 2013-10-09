//  AwfulThreadTagAndRatingView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulThreadTagAndRatingView vertically stacks a thread tag and a rating image.
 */
@interface AwfulThreadTagAndRatingView : UIView

/**
 * The thread tag to show on top.
 */
@property (strong, nonatomic) UIImage *threadTag;

/**
 * The secondary thread tag to lay over the thread tag. May be nil.
 */
@property (strong, nonatomic) UIImage *secondaryThreadTag;

/**
 * The rating image to show below. May be nil.
 */
@property (strong, nonatomic) UIImage *ratingImage;

@end
