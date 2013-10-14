//  AwfulURLRouter.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * An AwfulURLRouter translates URLs with the scheme "awful" into an appropriate shown screen.
 */
@interface AwfulURLRouter : NSObject

/**
 * Returns an initialized AwfulURLRouter. This is the designated initializer.
 *
 * @param rootViewController The application's root view controller.
 * @param managedObjectContext The managed object context we use to find forums, threads, and posts.
 */
- (id)initWithRootViewController:(UIViewController *)rootViewController
            managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * The root view controller used to find or show screens.
 */
@property (readonly, strong, nonatomic) UIViewController *rootViewController;

/**
 * The managed object context used to find forums, threads, and posts.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

/**
 * Show the screen appropriate for an "awful" URL.
 *
 * @param url A URL with the scheme "awful".
 *
 * @return YES if the URL was successfully routed, otherwise NO.
 */
- (BOOL)routeURL:(NSURL *)url;

@end
