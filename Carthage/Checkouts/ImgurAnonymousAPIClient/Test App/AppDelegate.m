//  AppDelegate.m
//
//  Public domain. https://github.com/nolanw/ImgurAnonymousAPIClient

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self.window makeKeyAndVisible];
    ViewController *viewController = (ViewController *)self.window.rootViewController;
    [viewController showImagePickerAnimated:NO];
    return YES;
}

@end
