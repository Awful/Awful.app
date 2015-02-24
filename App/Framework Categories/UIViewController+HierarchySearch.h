//  UIViewController+HierarchySearch.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIViewController (HierarchySearch)

/**
 * Searches the view controller hierarchy (rooted at this view controller) for a view controller of a particular type. Returns the first view controller found (using a depth-first search), or nil if no matching view controllers were found.
 */
- (id)awful_firstDescendantViewControllerOfClass:(Class)class;

@end
