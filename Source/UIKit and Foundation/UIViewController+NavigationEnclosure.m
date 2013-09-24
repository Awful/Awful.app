//  UIViewController+NavigationEnclosure.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+NavigationEnclosure.h"
#import "AwfulNavigationController.h"

@implementation UIViewController (NavigationEnclosure)

- (UINavigationController *)enclosingNavigationController
{
    if (self.navigationController) return self.navigationController;
    UINavigationController *nav = [[AwfulNavigationController alloc] initWithRootViewController:self];
    nav.modalPresentationStyle = self.modalPresentationStyle;
    return nav;
}

@end
