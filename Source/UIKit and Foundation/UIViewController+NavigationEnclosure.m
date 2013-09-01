//  UIViewController+NavigationEnclosure.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+NavigationEnclosure.h"
#import "AwfulNavigationBar.h"

@implementation UIViewController (NavigationEnclosure)

- (UINavigationController *)enclosingNavigationController
{
    if (self.navigationController) return self.navigationController;
    UINavigationController *nav = [[UINavigationController alloc]
                                   initWithNavigationBarClass:[AwfulNavigationBar class]
                                   toolbarClass:nil];
    nav.viewControllers = @[ self ];
    nav.modalPresentationStyle = self.modalPresentationStyle;
    return nav;
}

@end
