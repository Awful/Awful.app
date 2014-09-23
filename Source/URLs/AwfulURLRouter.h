//  AwfulURLRouter.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import "AwfulDataStack.h"

/**
 * An AwfulURLRouter translates URLs with the scheme "awful" into an appropriate shown screen.
 */
@interface AwfulURLRouter : NSObject

/**
 * @param rootViewController The application's root view controller.
 */
- (id)initWithRootViewController:(UIViewController *)rootViewController dataStack:(AwfulDataStack *)dataStack NS_DESIGNATED_INITIALIZER;

/**
 * The root view controller used to find or show screens.
 */
@property (readonly, strong, nonatomic) UIViewController *rootViewController;

/**
 * The managed object context used to find forums, threads, and posts.
 */
@property (readonly, strong, nonatomic) AwfulDataStack *dataStack;

/**
 * Show the screen appropriate for an "awful" URL.
 *
 * @param url A URL with the scheme "awful".
 *
 * @return YES if the URL was successfully routed, otherwise NO.
 */
- (BOOL)routeURL:(NSURL *)url;

@end
