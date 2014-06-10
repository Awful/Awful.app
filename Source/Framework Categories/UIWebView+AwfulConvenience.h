//  UIWebView+AwfulConvenience.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIWebView (AwfulConvenience)

/**
 * Returns the result of running a script specified as a format string.
 */
- (NSString *)awful_evalJavaScript:(NSString *)script, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Creates and returns a UIWebView suitable for displaying native content.
 */
+ (instancetype)awful_nativeFeelingWebView;

/**
 * Returns a CGRect in the web view corresponding to an element's offset.
 *
 * @param rectString A string, formatted appropriately for CGRectFromString, representing the element's client bounding rect.
 */
- (CGRect)awful_rectForElementBoundingRect:(NSString *)rectString;

/**
 * The percentage of the web view that's been scrolled down. Potentially more helpful than contentOffset when aiming for orientation indepdence.
 */
@property (assign, nonatomic, setter=awful_setFractionalContentOffset:) CGFloat awful_fractionalContentOffset;

@end
