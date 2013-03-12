//
//  UIViewController+AwfulTheming.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-08.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
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
