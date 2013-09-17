//  UIViewController+NavigationEnclosure.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+NavigationEnclosure.h"
#import "AwfulNavigationBar.h"
#import "AwfulToolbar.h"

@interface AwfulNavigationControllerFactory : NSObject <UIViewControllerRestoration>

+ (UINavigationController *)navigationController;

@end

@implementation UIViewController (NavigationEnclosure)

- (UINavigationController *)enclosingNavigationController
{
    if (self.navigationController) return self.navigationController;
    UINavigationController *nav = [AwfulNavigationControllerFactory navigationController];
    nav.viewControllers = @[ self ];
    nav.modalPresentationStyle = self.modalPresentationStyle;
    return nav;
}

@end

@implementation AwfulNavigationControllerFactory

+ (UINavigationController *)navigationController
{
    UINavigationController *nav = [[UINavigationController alloc] initWithNavigationBarClass:[AwfulNavigationBar class]
                                                                                toolbarClass:[AwfulToolbar class]];
    nav.restorationClass = self;
    return nav;
}

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    UINavigationController *nav = [self navigationController];
    nav.restorationIdentifier = identifierComponents.lastObject;
    return nav;
}

@end
