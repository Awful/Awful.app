//  AwfulNavigationController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationController.h"
#import "AwfulNavigationBar.h"
#import "AwfulToolbar.h"

@interface AwfulNavigationController () <UIViewControllerRestoration>

@end

@implementation AwfulNavigationController

// We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can.

- (id)init
{
    if (!(self = [self initWithNavigationBarClass:[AwfulNavigationBar class] toolbarClass:[AwfulToolbar class]])) return nil;
    self.restorationClass = self.class;
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if (!(self = [self init])) return nil;
    self.viewControllers = @[ rootViewController ];
    return self;
}

- (void)themeDidChange
{
	[super themeDidChange];
	
	self.navigationBar.tintColor = AwfulTheme.currentTheme[@"navigationBarTextColor"];
    self.navigationBar.barTintColor = AwfulTheme.currentTheme[@"navigationBarTintColor"];
}

#pragma mark UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    UINavigationController *nav = [self new];
    nav.restorationIdentifier = identifierComponents.lastObject;
    return nav;
}

@end
