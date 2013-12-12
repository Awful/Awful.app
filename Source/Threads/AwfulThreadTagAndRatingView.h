//  AwfulThreadTagAndRatingView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulThreadTagAndRatingView vertically stacks a thread tag and a rating image.
 */
@interface AwfulThreadTagAndRatingView : UIView

/**
 * The thread tag to show in the top two thirds.
 */
@property (strong, nonatomic) UIImage *threadTag;

/**
 * The secondary thread tag badge. If non-nil, laid over the bottom right corner of the thread tag.
 */
@property (strong, nonatomic) UIImage *secondaryThreadTag;

/**
 * The rating image to show in the bottom third. May be nil.
 */
@property (strong, nonatomic) UIImage *ratingImage;

@end
