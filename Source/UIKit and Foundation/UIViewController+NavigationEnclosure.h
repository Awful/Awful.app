//
//  UIViewController+NavigationEnclosure.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>

@interface UIViewController (NavigationEnclosure)

// Gets this view controller's navigation controller, lazily creating one if needed. If a navigation
// controller is created, it uses AwfulNavigationBar for its navigation bar and adopts the
// modalPresentationStyle of its root view controller.
@property (readonly, nonatomic) UINavigationController *enclosingNavigationController;

@end
