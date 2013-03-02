//
//  UIViewController+NavigationEnclosure.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-07.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
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
