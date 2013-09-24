//  UIViewController+AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import <objc/runtime.h>

@implementation UIViewController (AwfulTheme)

- (AwfulTheme *)theme
{
    AwfulTheme *theme = objc_getAssociatedObject(self, &ThemePropertyKey);
    if (!theme) {
        theme = self.parentViewController.theme;
    }
    if (!theme) {
        theme = self.presentingViewController.theme;
    }
    return theme;
}

- (void)setTheme:(AwfulTheme *)theme
{
    AwfulTheme *inheritedTheme = self.theme;
    objc_setAssociatedObject(self, &ThemePropertyKey, theme, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (inheritedTheme != theme) {
        RecursivelyCallThemeDidChangeOn(self);
    }
}

static const char ThemePropertyKey;

- (void)themeDidChange
{
    // noop
}

@end

@implementation AwfulViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    if (parent) {
        RecursivelyCallThemeDidChangeOn(self);
    }
}

@end

@implementation AwfulTableViewController

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    if (parent) {
        RecursivelyCallThemeDidChangeOn(self);
    }
}

@end

@implementation AwfulCollectionViewController

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    if (parent) {
        RecursivelyCallThemeDidChangeOn(self);
    }
}

@end

@implementation AwfulThemedNavigationController

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    if (parent) {
        RecursivelyCallThemeDidChangeOn(self);
    }
}

@end

void RecursivelyCallThemeDidChangeOn(UIViewController *viewController)
{
    if ([viewController isViewLoaded]) {
        [viewController themeDidChange];
    }
    for (UIViewController *child in viewController.childViewControllers) {
        if (!objc_getAssociatedObject(child, &ThemePropertyKey)) {
            RecursivelyCallThemeDidChangeOn(child);
        }
    }
    UIViewController *presented = viewController.presentedViewController;
    if (presented && !objc_getAssociatedObject(presented, &ThemePropertyKey)) {
        RecursivelyCallThemeDidChangeOn(presented);
    }
}
