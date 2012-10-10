//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulSplitViewController.h"
#import "AwfulSettings.h"
#import "AwfulLoginController.h"
#import "AwfulCSSTemplate.h"
#import "GRMustache.h"

@implementation AwfulAppDelegate

static AwfulAppDelegate *_instance;

+ (AwfulAppDelegate *)instance
{
    return _instance;
}

#pragma mark - Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _instance = self;
    [[AwfulSettings settings] registerDefaults];
    #if DEBUG
    [GRMustache preventNSUndefinedKeyExceptionAttack];
    #endif
    
    UITabBarController *tabBar;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.splitController = (AwfulSplitViewController *)self.window.rootViewController;
        tabBar = self.splitController.viewControllers[0];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        tabBar = (UITabBarController *)self.window.rootViewController;
    }
    if (!IsLoggedIn()) {
        tabBar.selectedIndex = 3;
    } else {
        tabBar.selectedIndex = [[AwfulSettings settings] firstTab];
    }
    
    [self configureAppearance];
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)configureAppearance
{
    id navBar = [UINavigationBar appearance];
    AwfulCSSTemplate *css = [AwfulCSSTemplate defaultTemplate];
    UIImage *portrait = [css navigationBarImageForMetrics:UIBarMetricsDefault];
    [navBar setBackgroundImage:portrait forBarMetrics:UIBarMetricsDefault];
    UIImage *landscape = [css navigationBarImageForMetrics:UIBarMetricsLandscapePhone];
    [navBar setBackgroundImage:landscape forBarMetrics:UIBarMetricsLandscapePhone];
    id navBarItem = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    [navBarItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1]];
    
    // On iPad, image pickers appear in popovers. And they look awful with the navigation bar and
    // bar item changes above. The obvious answer is to clear the customizations using
    // +appearanceWhenContainedIn:[UIPopoverController class], except the top-level split view
    // controller uses a popover to show the master view in portrait, so now it gets unstyled.
    // No problem, right? Just make a UIPopoverController subclass, clear its custom appearance,
    // and use that for the image picker popover. Except that still clears the appearance in the
    // split view controller's popover, even though it's not an instance of my subclass.
    // Not sure why.
    //
    // This works for now, though if we use popovers for other things we'll need to style them too.
    // (We'll use the default look for the picker on the phone too, it better matches the reply view.)
    id pickerNavBar = [UINavigationBar appearanceWhenContainedIn:[UIImagePickerController class], nil];
    [pickerNavBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [pickerNavBar setBackgroundImage:nil forBarMetrics:UIBarMetricsLandscapePhone];
    id pickerNavBarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
    [pickerNavBarItem setTintColor:nil];
}

#pragma mark - Relaying errors

- (void)requestFailed:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"Drats"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
