//
//  AppDelegate.m
//  CSS Tweaker
//
//  Created by Nolan Waite on 2013-03-15.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "AwfulActionSheet.h"
#import "ViewController.h"

@interface AppDelegate ()

@property (nonatomic) ViewController *viewController;

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.viewController = [ViewController new];
    self.viewController.title = @"Awful CSS Tweaker";
    UIBarButtonItem *tweak = [[UIBarButtonItem alloc] initWithTitle:@"Tweak"
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self action:@selector(tweak:)];
    self.viewController.navigationItem.leftBarButtonItem = tweak;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self.viewController];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)tweak:(UIBarButtonItem *)item
{
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    [sheet addButtonWithTitle:@"Toggle Dark Mode" block:^{
        [self.viewController toggleDarkMode];
    }];
    [sheet addButtonWithTitle:@"Change Stylesheet" block:^{
        [self changeStylesheet:item];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromBarButtonItem:item animated:YES];
}

- (void)changeStylesheet:(UIBarButtonItem *)item
{
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    #if TARGET_IPHONE_SIMULATOR
        #include "LessFilesPath.h"
        NSString *directory = LessFilesPath;
        NSString *suffix = @".less";
    #else
        NSString *directory = [[NSBundle mainBundle] resourcePath];
        NSString *suffix = @".css";
    #endif
    for (NSString *path in [[NSFileManager defaultManager] enumeratorAtPath:directory]) {
        NSString *filename = [path lastPathComponent];
        if ([filename hasSuffix:suffix] && [filename hasPrefix:@"posts-view"]) {
            [sheet addButtonWithTitle:[filename stringByDeletingPathExtension] block:^{
                [self.viewController loadStylesheetNamed:filename];
            }];
        }
    }
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromBarButtonItem:item animated:YES];
}

@end
