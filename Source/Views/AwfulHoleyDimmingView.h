//  AwfulHoleyDimmingView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulHoleyDimmingView dims a region of the screen around a hole.
 */
@interface AwfulHoleyDimmingView : UIView

/**
 * A region of the dimming view to dim. Default is an infinite CGRect indicating the entire bounds. This allows the dimming view to cover a larger area than is actually dimmed (perhaps to intercept taps).
 */
@property (assign, nonatomic) CGRect dimRect;

/**
 * A region of the dimmingRect in which no dimming whatsoever should occur. Default is an empty CGRect indicating no hole.
 */
@property (assign, nonatomic) CGRect hole;

@end
