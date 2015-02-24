//  UIViewController+HierarchySearch.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+HierarchySearch.h"

@implementation UIViewController (HierarchySearch)

- (id)awful_firstDescendantViewControllerOfClass:(Class)class
{
    if ([self isKindOfClass:class]) return self;
    if ([self respondsToSelector:@selector(viewControllers)]) {
        for (UIViewController *child in [self valueForKey:@"viewControllers"]) {
            id found = [child awful_firstDescendantViewControllerOfClass:class];
            if (found) return found;
        }
    }
    return nil;
}

@end
