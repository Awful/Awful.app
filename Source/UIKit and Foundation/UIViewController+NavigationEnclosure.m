//
//  UIViewController+NavigationEnclosure.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

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
