//
//  AwfulThreadTagAndRatingView.h
//  Awful
//
//  Created by Nolan Waite on 2013-09-10.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
