//  AwfulThreadTagAndRatingView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulThreadTagAndRatingView vertically stacks a thread tag and a rating image, and overlays the thread tag with a secondary thread tag.
 */
@interface AwfulThreadTagAndRatingView : UIView

@property (strong, nonatomic) UIImage *threadTagImage;

@property (strong, nonatomic) UIImage *secondaryThreadTagImage;

@property (strong, nonatomic) UIImage *ratingImage;

@end
