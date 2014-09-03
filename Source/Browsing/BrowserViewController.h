//  BrowserViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

/**
 * A BrowserViewController displays web content with a minimal browser interface. If presented, the left navigation item is a "Close" button that dismisses the view controller.
 */
@interface BrowserViewController : AwfulViewController

/**
 * Convenience initializer.
 */
- (id)initWithURL:(NSURL *)URL;

/**
 * The URL of the current page.
 */
@property (strong, nonatomic) NSURL *URL;

/**
 * Convenience method to show an Awful Browser in a user interface idiom-appropriate manner. The AwfulBrowserViewController has its restorationIdentifier set.
 */
+ (instancetype)presentBrowserForURL:(NSURL *)URL fromViewController:(UIViewController *)presentingViewController;

@end
