//
//  UIViewController+AwfulTheming.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "UIViewController+AwfulTheming.h"
#import "AwfulThemingViewController.h"

@implementation UIViewController (AwfulTheming)

- (void)recursivelyRetheme
{
    if ([self isViewLoaded] && [self conformsToProtocol:@protocol(AwfulThemingViewController)]) {
        [(id)self retheme];
    }
    // presentedViewController can be a view controller presented by one of our ancestors, in which
    // case we'll let them do the retheming so we don't repeat the work.
    UIViewController *presented = self.presentedViewController;
    if (presented && ![presented isEqual:self.parentViewController.presentedViewController]) {
        [presented recursivelyRetheme];
    }
    if ([self respondsToSelector:@selector(viewControllers)]) {
        [[(id)self viewControllers] makeObjectsPerformSelector:@selector(recursivelyRetheme)];
    }
}

@end
