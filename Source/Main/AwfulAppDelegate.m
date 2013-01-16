//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulAlertView.h"
#import "AwfulBookmarksController.h"
#import "AwfulDataStack.h"
#import "AwfulFavoritesViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulNavigationBar.h"
#import "AwfulPostsViewController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulSplitViewController.h"
#import "AwfulStartViewController.h"
#import "AwfulTabBarController.h"
#import "AFNetworking.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "SVProgressHUD.h"
#import "UIViewController+NavigationEnclosure.h"
#import "AwfulAppState.h"

@interface AwfulAppDelegate () <AwfulTabBarControllerDelegate, UINavigationControllerDelegate,
                                AwfulLoginControllerDelegate>

@property (weak, nonatomic) AwfulSplitViewController *splitViewController;

@property (weak, nonatomic) AwfulTabBarController *tabBarController;

@end


@implementation AwfulAppDelegate

static AwfulAppDelegate *_instance;

+ (AwfulAppDelegate *)instance
{
    return _instance;
}

- (void)showLoginFormAtLaunch
{
    [self showLoginFormIsAtLaunch:YES andThen:nil];
}

- (void)showLoginFormIsAtLaunch:(BOOL)isAtLaunch andThen:(void (^)(void))callback
{
    AwfulLoginController *login = [AwfulLoginController new];
    login.delegate = self;
    UINavigationController *nav = [login enclosingNavigationController];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    BOOL animated = !isAtLaunch || UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    [self.window.rootViewController presentViewController:nav
                                                 animated:animated
                                               completion:callback];
}

- (void)logOut
{
    NSURL *sa = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:sa];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    [AwfulAppState.sharedAppState clearCloudCookies];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    AwfulSettings.settings.username = nil;
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[AwfulDataStack sharedDataStack] deleteAllDataAndResetStack];
    
    [self showLoginFormIsAtLaunch:NO andThen:^{
        AwfulTabBarController *tabBar;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
            tabBar = split.viewControllers[0];
        } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            tabBar = (AwfulTabBarController *)self.window.rootViewController;
        }
        tabBar.selectedViewController = tabBar.viewControllers[0];
    }];
}

- (void)configureAppearance
{
    // Including a navbar.png (i.e. @1x), or setting a background image for
    // UIBarMetricsLandscapePhone, makes the background come out completely different for some
    // unknown reason on non-retina devices and in landscape on the phone. I'm out of ideas.
    // Simply setting UIBarMetricsDefault and only including navbar@2x.png works great on retina
    // and non-retina devices alike, so that's where I'm leaving it.
    AwfulNavigationBar *navBar = [AwfulNavigationBar appearance];
    UIImage *barImage = [UIImage imageNamed:@"navbar.png"];
    [navBar setBackgroundImage:barImage forBarMetrics:UIBarMetricsDefault];
    [navBar setTitleTextAttributes:@{
        UITextAttributeTextColor : [UIColor whiteColor],
        UITextAttributeTextShadowColor : [UIColor colorWithWhite:0 alpha:0.5]
    }];
    
    UIBarButtonItem *navBarItem = [UIBarButtonItem appearanceWhenContainedIn:
                                   [AwfulNavigationBar class], nil];
    UIImage *navBarButton = [UIImage imageNamed:@"navbar-button.png"];
    [navBarItem setBackgroundImage:navBarButton
                          forState:UIControlStateNormal
                        barMetrics:UIBarMetricsDefault];
    UIImage *navBarLandscapeButton = [[UIImage imageNamed:@"navbar-button-landscape.png"]
                                      resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6, 0, 6)];
    [navBarItem setBackgroundImage:navBarLandscapeButton
                          forState:UIControlStateNormal
                        barMetrics:UIBarMetricsLandscapePhone];
    UIImage *backButton = [[UIImage imageNamed:@"navbar-back.png"]
                           resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13, 0, 6)];
    [navBarItem setBackButtonBackgroundImage:backButton
                                    forState:UIControlStateNormal
                                  barMetrics:UIBarMetricsDefault];
    UIImage *landscapeBackButton = [[UIImage imageNamed:@"navbar-back-landscape.png"]
                                    resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13, 0, 6)];
    [navBarItem setBackButtonBackgroundImage:landscapeBackButton
                                    forState:UIControlStateNormal
                                  barMetrics:UIBarMetricsLandscapePhone];
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _instance = self;
    [[AwfulSettings settings] registerDefaults];
    [AwfulDataStack sharedDataStack].initFailureAction = AwfulDataStackInitFailureDelete;
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    NSUInteger sixtyMB = 1024 * 1024 * 60;
    if ([[NSURLCache sharedURLCache] diskCapacity] < sixtyMB) {
        [[NSURLCache sharedURLCache] setDiskCapacity:sixtyMB];
    }
    
    [self iCloudSetup];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    AwfulTabBarController *tabBar = [AwfulTabBarController new];
    tabBar.viewControllers = @[
        [[AwfulForumsListController new] enclosingNavigationController],
        [[AwfulFavoritesViewController new] enclosingNavigationController],
        [[AwfulBookmarksController new] enclosingNavigationController],
        [[AwfulSettingsViewController new] enclosingNavigationController]
    ];
    //tabBar.selectedViewController = tabBar.viewControllers[[[AwfulSettings settings] firstTab]];
    tabBar.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        AwfulSplitViewController *splitController = [AwfulSplitViewController new];
        AwfulStartViewController *start = [AwfulStartViewController new];
        UINavigationController *nav = [start enclosingNavigationController];
        nav.delegate = self;
        splitController.viewControllers = @[ tabBar, nav ];
        self.window.rootViewController = splitController;
        self.splitViewController = splitController;
    } else {
        self.window.rootViewController = tabBar;
    }
    self.tabBarController = tabBar;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSFileManager *fileman = [NSFileManager defaultManager];
        NSURL *cssReadme = [[NSBundle mainBundle] URLForResource:@"Custom CSS README"
                                                   withExtension:@"txt"];
        NSURL *documents = [fileman documentDirectory];
        NSURL *readmeDestination = [documents URLByAppendingPathComponent:@"README.txt"];
        NSError *error;
        BOOL ok = [fileman copyItemAtURL:cssReadme
                                   toURL:readmeDestination
                                   error:&error];
        if (!ok && [error code] != NSFileWriteFileExistsError) {
            NSLog(@"error copying README.txt to documents: %@", error);
        }
        NSURL *exampleCSS = [[NSBundle mainBundle] URLForResource:@"posts-view"
                                                    withExtension:@"css"];
        NSURL *cssDestination = [documents URLByAppendingPathComponent:@"example-posts-view.css"];
        ok = [fileman copyItemAtURL:exampleCSS toURL:cssDestination error:&error];
        if (!ok && [error code] != NSFileWriteFileExistsError) {
            NSLog(@"error copying example-posts-view.css to documents: %@", error);
        }
        NSURL *oldData = [documents URLByAppendingPathComponent:@"AwfulData.sqlite"];
        ok = [fileman removeItemAtURL:oldData error:&error];
        if (!ok && [error code] != NSFileNoSuchFileError) {
            NSLog(@"error deleting Documents/AwfulData.sqlite: %@", error);
        }
    });
    
    [self configureAppearance];
    
    [self.window makeKeyAndVisible];
    
    if (!IsLoggedIn()) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self performSelector:@selector(showLoginFormAtLaunch) withObject:nil afterDelay:0];
        } else {
            [self showLoginFormAtLaunch];
        }
    }
    
    if (IsLoggedIn() && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
        [split performSelector:@selector(showMasterView) withObject:nil afterDelay:0.1];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if ([[url scheme] compare:@"awful" options:NSCaseInsensitiveSearch] != NSOrderedSame) return NO;
    if (!IsLoggedIn()) return NO;
    
    NSString *section = [url host];
    
    // Open the forums list: awful://forums
    // Open a specific forum from the list: awful://forums/:forumID
    // Open the favorites list: awful://favorites
    // Open a specific forum from the favorites: awful://favorites/:forumID
    if ([section isEqualToString:@"forums"] || [section isEqualToString:@"favorites"]) {
        AwfulForum *forum;
        // First path component is the /
        if ([[url pathComponents] count] > 1) {
            forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", [url pathComponents][1]];
        }
        UINavigationController *nav = self.tabBarController.viewControllers[0];
        if ([section isEqualToString:@"favorites"]) {
            if (!forum || forum.isFavoriteValue) {
                nav = self.tabBarController.viewControllers[1];
            }
        }
        [self jumpToForum:forum inNavigationController:nav];
        self.tabBarController.selectedViewController = nav;
        [self.splitViewController showMasterView];
    }
    
    // Open bookmarks: awful://bookmarks
    if ([section isEqualToString:@"bookmarks"]) {
        UINavigationController *nav = self.tabBarController.viewControllers[2];
        [nav popToRootViewControllerAnimated:YES];
        self.tabBarController.selectedViewController = nav;
    }
    
    // Open settings: awful://settings
    if ([section isEqualToString:@"settings"]) {
        UINavigationController *nav = self.tabBarController.viewControllers[3];
        [nav popToRootViewControllerAnimated:YES];
        self.tabBarController.selectedViewController = nav;
    }
    
    // Open a thread: awful://threads/:threadID
    // Open a specific page of a thread: awful://threads/:threadID/pages/:page
    //     :page may be a positive integer, the text "last", or the text "unread".
    if ([section isEqualToString:@"threads"]) {
        // First path component is the /
        if ([[url pathComponents] count] < 2) return NO;
        NSString *threadID = [url pathComponents][1];
        NSInteger page = 0;
        if ([[url pathComponents] count] >= 4) {
            if ([[url pathComponents][2] isEqualToString:@"pages"]) {
                NSString *pageString = [url pathComponents][3];
                if ([pageString isEqualToString:@"last"]) page = AwfulPageLast;
                else if ([pageString isEqualToString:@"unread"]) page = AwfulPageNextUnread;
                else page = [pageString integerValue];
            }
        }
        // Maybe the thread is already open.
        NSArray *maybes = self.tabBarController.viewControllers;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            maybes = @[ self.splitViewController.viewControllers[1] ];
        }
        for (UIViewController *viewController in maybes) {
            UINavigationController *nav = (UINavigationController *)viewController;
            AwfulPostsViewController *top = (AwfulPostsViewController *)nav.topViewController;
            if (![top isKindOfClass:[AwfulPostsViewController class]]) continue;
            if ([top.threadID isEqualToString:threadID]) {
                if (page == 0 || page == top.currentPage) {
                    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
                        self.tabBarController.selectedViewController = nav;
                    }
                    return YES;
                }
            }
        }
        if (page == 0) page = 1;
        AwfulPostsViewController *postsView = [AwfulPostsViewController new];
        postsView.threadID = threadID;
        [postsView loadPage:page];
        UINavigationController *nav;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            nav = self.splitViewController.viewControllers[1];
            if (![nav.topViewController isKindOfClass:[AwfulPostsViewController class]]) {
                [nav setViewControllers:@[ postsView ] animated:YES];
                return YES;
            }
        } else {
            nav = (UINavigationController *)self.tabBarController.selectedViewController;
        }
        [nav pushViewController:postsView animated:YES];
    }
    
    // Open a post: awful://posts/:postID
    if ([section isEqualToString:@"posts"]) {
        if ([[url pathComponents] count] < 2) return NO;
        NSString *postID = [url pathComponents][1];
        // Is the post in a thread that's already open?
        NSArray *maybes = self.tabBarController.viewControllers;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            maybes = @[ self.splitViewController.viewControllers[1] ];
        }
        for (UIViewController *viewController in maybes) {
            UINavigationController *nav = (UINavigationController *)viewController;
            AwfulPostsViewController *top = (AwfulPostsViewController *)nav.topViewController;
            if (![top isKindOfClass:[AwfulPostsViewController class]]) continue;
            if ([[top.posts valueForKey:@"postID"] containsObject:postID]) {
                if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
                    self.tabBarController.selectedViewController = nav;
                }
                [top jumpToPostWithID:postID];
                return YES;
            }
        }
        // Have we seen the post before?
        AwfulPost *post = [AwfulPost firstMatchingPredicate:@"postID = %@", postID];
        if (post) {
            [self pushPostsViewForPostWithID:post.postID
                                      onPage:post.threadPageValue
                              ofThreadWithID:post.thread.threadID];
            return YES;
        }
        // Gotta go find it then.
        [SVProgressHUD showWithStatus:@"Locating Post"];
        [[AwfulHTTPClient client] locatePostWithID:postID andThen:^(NSError *error,
                                                                    NSString *threadID,
                                                                    NSInteger page)
         {
             if (error) {
                 [SVProgressHUD showErrorWithStatus:@"Post Not Found"];
                 NSLog(@"couldn't find post for tapped link %@: %@", url, error);
                 return;
             }
             [SVProgressHUD dismiss];
             [self pushPostsViewForPostWithID:postID onPage:page ofThreadWithID:threadID];
         }];
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[AwfulDataStack sharedDataStack] save];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[AwfulDataStack sharedDataStack] save];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[AwfulDataStack sharedDataStack] save];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[AwfulDataStack sharedDataStack] save];
}

#pragma mark navigation

- (void)pushPostsViewForPostWithID:(NSString *)postID
                            onPage:(NSInteger)page
                    ofThreadWithID:(NSString *)threadID
{
    AwfulPostsViewController *postsView = [AwfulPostsViewController new];
    postsView.threadID = threadID;
    [postsView loadPage:page];
    [postsView jumpToPostWithID:postID];
    UINavigationController *nav;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nav = self.splitViewController.viewControllers[1];
        if (![nav.topViewController isKindOfClass:[AwfulPostsViewController class]]) {
            [nav setViewControllers:@[ postsView ] animated:YES];
            return;
        }
    } else {
        nav = (UINavigationController *)self.tabBarController.selectedViewController;
    }
    [nav pushViewController:postsView animated:YES];
}

- (void)jumpToForum:(AwfulForum *)forum inNavigationController:(UINavigationController *)nav
{
    if (!forum) {
        [nav popToRootViewControllerAnimated:YES];
        return;
    }
    NSMutableArray *maybes = [@[ nav.topViewController ] mutableCopy];
    if ([nav.viewControllers count] > 1) {
        [maybes insertObject:nav.viewControllers[[nav.viewControllers count] - 2] atIndex:0];
    }
    for (AwfulThreadListController *viewController in maybes) {
        if (![viewController isKindOfClass:[AwfulThreadListController class]]) continue;
        if ([viewController.forum isEqual:forum]) {
            [nav popToViewController:viewController animated:YES];
            return;
        }
    }
    [nav popToRootViewControllerAnimated:NO];
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [nav pushViewController:threadList animated:YES];
}

#pragma mark - AwfulTabBarControllerDelegate

- (BOOL)tabBarController:(AwfulTabBarController *)tabBarController
    shouldSelectViewController:(UIViewController *)viewController
{
    return IsLoggedIn();
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [self.splitViewController ensureLeftBarButtonItemOnDetailView];
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginControllerDidLogIn:(AwfulLoginController *)login
{
    [[AwfulAppState sharedAppState] syncForumCookies];
    [[AwfulHTTPClient client] learnUserInfoAndThen:^(NSError *error, NSDictionary *userInfo) {
        if (error) {
            NSLog(@"error fetching username: %@", error);
        } else {
            [AwfulSettings settings].username = userInfo[@"username"];
        }
    }];
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[AwfulHTTPClient client] listForumsAndThen:nil];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
            [split showMasterView];
        }
    }];
}

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error
{
    [AwfulAlertView showWithTitle:@"Problem Logging In"
                          message:@"Double-check your username and password, then try again."
                      buttonTitle:@"Alright"
                       completion:nil];
}

#pragma mark iCloud Sync Handlers

- (void)iCloudSetup
{
    // register to observe notifications from the store
    [[NSNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector (storeDidChange:)
     name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
     object: [NSUbiquitousKeyValueStore defaultStore]];
    
    // get changes that might have happened while this
    // instance of your app wasn't running
    [[NSUbiquitousKeyValueStore defaultStore] synchronize];
    [[AwfulAppState sharedAppState] syncForumCookies];
    
    //[[AwfulDataStack sharedDataStack] loadPersistentStores];
}

- (void)storeDidChange:(NSNotification*)notification
{
    NSArray *changes = [notification.userInfo objectForKey:NSUbiquitousKeyValueStoreChangedKeysKey];
    NSLog(@"changes=%@",changes);
    if ([changes containsObject:kAwfulAppStateForumCookieData]) {
        BOOL loggedInBeforeSync = IsLoggedIn();
        [[AwfulAppState sharedAppState] syncForumCookies];
        if(!loggedInBeforeSync && IsLoggedIn()) {
            //just synced forum cookies, user doesn't need to log in now
            [self loginControllerDidLogIn:nil];
        }
    }
    
    if ([changes containsObject:kAwfulAppStateFavoriteForums]) {
        [[AwfulAppState sharedAppState] syncCloudFavorites];
    }
    
    if ([changes containsObject:kAwfulAppStateExpandedForums]) {
        [[AwfulAppState sharedAppState] syncCloudExpanded];
    }
    
}

@end
