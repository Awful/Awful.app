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

@interface AwfulAppDelegate () <AwfulLoginControllerDelegate>

@end


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
    [AwfulDataStack sharedDataStack].initFailureAction = AwfulDataStackInitFailureDelete;
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSFileManager *fileman = [NSFileManager defaultManager];
        NSURL *cssReadme = [[NSBundle mainBundle] URLForResource:@"README"
                                                   withExtension:@"txt"];
        NSURL *documents = [[fileman URLsForDirectory:NSDocumentDirectory
                                            inDomains:NSUserDomainMask] lastObject];
        NSURL *destination = [documents URLByAppendingPathComponent:@"README.txt"];
        NSError *error;
        BOOL ok = [fileman copyItemAtURL:cssReadme
                                   toURL:destination
                                   error:&error];
        if (!ok && [error code] != NSFileWriteFileExistsError) {
            NSLog(@"error copying README.txt to documents: %@", error);
        }
    });
    
    [self configureAppearance];
    
    [self.window makeKeyAndVisible];
    
    if (!IsLoggedIn()) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self performSelector:@selector(showLogin) withObject:nil afterDelay:0];
        } else {
            [self showLogin];
        }
    }
    
    return YES;
}

- (void)showLogin
{
    AwfulLoginController *login = [AwfulLoginController new];
    login.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.window.rootViewController presentViewController:nav
                                                 animated:UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
                                               completion:nil];
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

#pragma mark - AwfulLoginControllerDelegate

- (void)loginControllerDidLogIn:(AwfulLoginController *)login
{
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[AwfulHTTPClient sharedClient] forumsListOnCompletion:nil onError:nil];
    }];
}

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error
{
    UIAlertView *alert = [UIAlertView new];
    alert.title = @"Problem Logging In";
    alert.message = @"Double-check your username and password, then try again.";
    [alert addButtonWithTitle:@"Alright"];
    [alert show];
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
