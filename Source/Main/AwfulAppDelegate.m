//
//  AwfulAppDelegate.m
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulAppDelegate.h"
#import "AwfulAlertView.h"
#import "AwfulBookmarksController.h"
#import "AwfulCrashlytics.h"
#import "AwfulDataStack.h"
#import "AwfulForumsListController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulNavigationBar.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPostsViewController.h"
#import "AwfulPrivateMessageListController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulSplitViewController.h"
#import "AwfulStartViewController.h"
#import "AwfulTabBarController.h"
#import "AwfulTheme.h"
#import "AFNetworking.h"
#import <AVFoundation/AVFoundation.h>
#import <Crashlytics/Crashlytics.h>
#import "JLRoutes.h"
#import "NSFileManager+UserDirectories.h"
#import "NSURL+Awful.h"
#import "NSURL+Punycode.h"
#import "NSManagedObject+Awful.h"
#import "SVProgressHUD.h"
#import "UIViewController+AwfulTheming.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulAppDelegate () <AwfulTabBarControllerDelegate, UINavigationControllerDelegate,
                                AwfulLoginControllerDelegate, AwfulSplitViewControllerDelegate>

@property (weak, nonatomic) AwfulSplitViewController *splitViewController;
@property (nonatomic) UIBarButtonItem *showSidebarButtonItem;
@property (weak, nonatomic) AwfulTabBarController *tabBarController;

@end


@implementation AwfulAppDelegate

static id _instance;

+ (instancetype)instance
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
    // Reset the HTTP client so it gets remade (if necessary) with the default URL.
    [AwfulHTTPClient reset];
    
    // Delete all cookies, both from SA and possibly accrued from using Awful Browser.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    
    // Empty the URL cache.
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Reset all preferences.
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    
    // Delete cached post info. The next user might see things differently than the one logging out.
    // And this lets logging out double as a "delete all data" button.
    [[AwfulDataStack sharedDataStack] deleteAllDataAndResetStack];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulUserDidLogOutNotification
                                                        object:nil];
    
    [self setUpRootViewController];
    
    [self showLoginFormIsAtLaunch:NO andThen:^{
        AwfulTabBarController *tabBar = self.tabBarController;
        tabBar.selectedViewController = tabBar.viewControllers[0];
        if (self.splitViewController) {
            UINavigationController *main = (id)self.splitViewController.mainViewController;
            main.viewControllers = @[ [AwfulStartViewController new] ];
        }
    }];
}

NSString * const AwfulUserDidLogOutNotification = @"com.awfulapp.Awful.UserDidLogOutNotification";

- (UIBarButtonItem *)showSidebarButtonItem
{
    if (_showSidebarButtonItem) return _showSidebarButtonItem;
    UIImage *listIcon = [UIImage imageNamed:@"list_icon.png"];
    _showSidebarButtonItem = [[UIBarButtonItem alloc] initWithImage:listIcon
                                                                style:UIBarButtonItemStyleBordered
                                                               target:self
                                                               action:@selector(didTapShowSidebar)];
    _showSidebarButtonItem.accessibilityLabel = @"Sidebar";
    return _showSidebarButtonItem;
}

- (void)didTapShowSidebar
{
    [self.splitViewController setSidebarVisible:YES animated:YES];
}

- (void)setUpRootViewController
{
    AwfulTabBarController *tabBar = [AwfulTabBarController new];
    tabBar.viewControllers = @[
        [[AwfulForumsListController new] enclosingNavigationController],
        [[AwfulPrivateMessageListController new] enclosingNavigationController],
        [[AwfulBookmarksController new] enclosingNavigationController],
        [[AwfulSettingsViewController new] enclosingNavigationController]
    ];
    tabBar.selectedViewController = tabBar.viewControllers[[[AwfulSettings settings] firstTab]];
    tabBar.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        AwfulStartViewController *start = [AwfulStartViewController new];
        UINavigationController *main = [start enclosingNavigationController];
        main.delegate = self;
        AwfulSplitViewController *split;
        split = [[AwfulSplitViewController alloc] initWithSidebarViewController:tabBar
                                                             mainViewController:main];
        split.delegate = self;
        self.window.rootViewController = split;
        self.splitViewController = split;
    } else {
        self.window.rootViewController = tabBar;
    }
    self.tabBarController = tabBar;
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
    #if defined(CRASHLYTICS_API_KEY) && !DEBUG
    [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
    #endif
    [[AwfulSettings settings] registerDefaults];
    [AwfulDataStack sharedDataStack].initFailureAction = AwfulDataStackInitFailureDelete;
    // Migrate Core Data early to avoid problems later!
    [[AwfulDataStack sharedDataStack] context];
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:5 * 1024 * 1024
                                                         diskCapacity:50 * 1024 * 1024
                                                             diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
    [self ignoreSilentSwitchWhenPlayingEmbeddedVideo];
    
    [self routeAwfulURLs];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    [self setUpRootViewController];
        
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
    
    if (![AwfulHTTPClient client].loggedIn) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self performSelector:@selector(showLoginFormAtLaunch) withObject:nil afterDelay:0];
        } else {
            [self showLoginFormAtLaunch];
        }
    }
    
    if ([AwfulHTTPClient client].loggedIn) {
        [self.splitViewController setSidebarVisible:YES animated:YES];
    }
    
    // Sometimes new features depend on the currently logged in user's info. We update that info on
    // login, and when visiting the Settings tab. But that leaves out people who update to a new
    // version of Awful and don't visit the Settings tab. For example, when adding PM support, we'd
    // erroneously assume they can't send PMs because we'd simply never checked. This will ensure
    // we update user info at least once for each new version of Awful.
    if ([AwfulHTTPClient client].loggedIn) {
        NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
        NSString *lastCheck = [AwfulSettings settings].lastForcedUserInfoUpdateVersion;
        if ([appVersion compare:lastCheck options:NSNumericSearch] == NSOrderedDescending) {
            [[AwfulHTTPClient client] learnUserInfoAndThen:^(NSError *error, NSDictionary *userInfo) {
                if (error) {
                    NSLog(@"error forcing user info update: %@", error);
                    return;
                }
                [AwfulSettings settings].lastForcedUserInfoUpdateVersion = appVersion;
                [AwfulSettings settings].userID = userInfo[@"userID"];
                [AwfulSettings settings].username = userInfo[@"username"];
                [AwfulSettings settings].canSendPrivateMessages = [userInfo[@"canSendPrivateMessages"] boolValue];
            }];
        }
    }
    
    [[AwfulNewPMNotifierAgent agent] checkForNewMessages];
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(themeDidChange:)
                       name:AwfulThemeDidChangeNotification object:nil];
    if (self.splitViewController) {
        [noteCenter addObserver:self selector:@selector(settingsDidChange:)
                           name:AwfulSettingsDidChangeNotification object:nil];
    }
    return YES;
}

- (void)themeDidChange:(NSNotification *)note
{
    [self.window.rootViewController recursivelyRetheme];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *settings = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([settings containsObject:AwfulSettingsKeys.keepSidebarOpen]) {
        AwfulSplitViewController *split = self.splitViewController;
        split.sidebarCanHide = [self awfulSplitViewController:split
                               shouldHideSidebarInOrientation:split.interfaceOrientation];
        [self ensureShowSidebarButtonInMainViewController];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[AwfulNewPMNotifierAgent agent] checkForNewMessages];
}

- (void)ignoreSilentSwitchWhenPlayingEmbeddedVideo
{
    NSError *error;
    BOOL ok = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                                     error:&error];
    if (!ok) {
        NSLog(@"error setting shared audio session category: %@", error);
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (![AwfulHTTPClient client].loggedIn) return;
	// Get a URL from the pasteboard, and fallback to checking the string pasteboard
	// in case some app is a big jerk and only sets a string value.
    NSURL *url = [UIPasteboard generalPasteboard].URL;
    if (!url) {
        url = [NSURL awful_URLWithString:[UIPasteboard generalPasteboard].string];
    }
    if (![url awfulURL]) return;
    // Don't ask about the same URL over and over.
    if ([[AwfulSettings settings].lastOfferedPasteboardURL isEqualToString:[url absoluteString]]) {
        return;
    }
    [AwfulSettings settings].lastOfferedPasteboardURL = [url absoluteString];
    NSMutableString *abbreviatedURL = [[url awful_absoluteUnicodeString] mutableCopy];
    NSRange upToHost = [abbreviatedURL rangeOfString:@"://"];
    if (upToHost.location == NSNotFound) {
        upToHost = [abbreviatedURL rangeOfString:@":"];
    }
    if (upToHost.location != NSNotFound) {
        upToHost.length += upToHost.location;
        upToHost.location = 0;
        [abbreviatedURL deleteCharactersInRange:upToHost];
    }
    if ([abbreviatedURL length] > 60) {
        [abbreviatedURL replaceCharactersInRange:NSMakeRange(55, [abbreviatedURL length] - 55)
                                      withString:@"…"];
    }
    NSString *message = [NSString stringWithFormat:@"Would you like to open this URL in Awful?\n\n%@", abbreviatedURL];
		[AwfulAlertView showWithTitle:@"Open in Awful"
                              message:message
                        noButtonTitle:@"Cancel"
                       yesButtonTitle:@"Open"
                         onAcceptance:^{ [[UIApplication sharedApplication] openURL:[url awfulURL]]; }];
}

#pragma mark - awful:// URL scheme

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if ([[url scheme] compare:@"awful" options:NSCaseInsensitiveSearch] != NSOrderedSame) return NO;
    if (![AwfulHTTPClient client].loggedIn) return NO;
    return [JLRoutes routeURL:url];
}

- (void)routeAwfulURLs
{
    void (^jumpToForum)(NSString *) = ^(NSString *forumID) {
        AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", forumID];
        UINavigationController *nav = self.tabBarController.viewControllers[0];
        [self jumpToForum:forum inNavigationController:nav];
        [self.splitViewController setSidebarVisible:YES animated:YES];
    };
    
    [JLRoutes addRoute:@"/forums/:forumID" handler:^(NSDictionary *params) {
        jumpToForum(params[@"forumID"]);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/forums" handler:^(id _) {
        self.tabBarController.selectedViewController = self.tabBarController.viewControllers[0];
        [self.splitViewController setSidebarVisible:YES animated:YES];
        return YES;
    }];
    
    void (^selectAndPopViewControllerAtIndex)(NSInteger) = ^(NSInteger i) {
        UINavigationController *nav = self.tabBarController.viewControllers[i];
        [nav popToRootViewControllerAnimated:YES];
        self.tabBarController.selectedViewController = nav;
        [self.splitViewController setSidebarVisible:YES animated:YES];
    };
    
    [JLRoutes addRoute:@"/messages" handler:^(id _) {
        selectAndPopViewControllerAtIndex(1);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/bookmarks" handler:^(id _) {
        selectAndPopViewControllerAtIndex(2);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/settings" handler:^(id _) {
        selectAndPopViewControllerAtIndex(3);
        return YES;
    }];
    
    void (^openThread)(NSDictionary *) = ^(NSDictionary *params) {
        NSInteger page = 0;
        if ([params[@"page"] isEqual:@"last"]) {
            page = AwfulThreadPageLast;
        } else if ([params[@"page"] isEqual:@"unread"]) {
            page = AwfulThreadPageNextUnread;
        } else {
            page = [params[@"page"] integerValue];
        }
        
        // Maybe the thread is already open.
        // On iPhone, could be in any tab, but on iPad, there's only one navigation controller for
        // posts view controllers.
        NSArray *maybes = self.tabBarController.viewControllers;
        if (self.splitViewController) {
            maybes = @[ self.splitViewController.mainViewController ];
        }
        for (UINavigationController *nav in maybes) {
            AwfulPostsViewController *top = (id)nav.topViewController;
            if (![top isKindOfClass:[AwfulPostsViewController class]]) continue;
            if ([top.thread.threadID isEqual:params[@"threadID"]]) {
                if ((page == 0 || page == top.currentPage) &&
                    top.singleUserID == params[@"userid"]) {
                    if ([maybes count] > 1) {
                        self.tabBarController.selectedViewController = nav;
                    }
                    return;
                }
            }
        }
        
        // Load the thread in a new posts view.
        AwfulPostsViewController *postsView = [AwfulPostsViewController new];
        postsView.thread = [AwfulThread firstOrNewThreadWithThreadID:params[@"threadID"]];
        if (page == 0) {
            page = 1;
        }
        [postsView loadPage:page singleUserID:params[@"userid"]];
        UINavigationController *nav;
        if (self.splitViewController) {
            nav = (id)self.splitViewController.mainViewController;
        } else {
            nav = (id)self.tabBarController.selectedViewController;
        }
        
        // On iPad, the app launches with a tag collage as its detail view. A posts view needs to
        // replace this collage, not be pushed on top.
        if (self.splitViewController &&
            ![nav.topViewController isKindOfClass:[AwfulPostsViewController class]]) {
            [nav setViewControllers:@[ postsView ] animated:YES];
        } else {
            [nav pushViewController:postsView animated:YES];
        }
    };
    
    [JLRoutes addRoute:@"/threads/:threadID/pages/:page" handler:^(NSDictionary *params) {
        openThread(params);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/threads/:threadID" handler:^(NSDictionary *params) {
        openThread(params);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/posts/:postID" handler:^(NSDictionary *params) {
        // Maybe the post is already visible.
        NSArray *maybes = self.tabBarController.viewControllers;
        if (self.splitViewController) {
            maybes = @[ self.splitViewController.mainViewController ];
        }
        for (UINavigationController *nav in maybes) {
            AwfulPostsViewController *top = (id)nav.topViewController;
            if (![top isKindOfClass:[AwfulPostsViewController class]]) continue;
            if ([[top.posts valueForKey:@"postID"] containsObject:params[@"postID"]]) {
                if (!self.splitViewController) {
                    self.tabBarController.selectedViewController = nav;
                }
                [top jumpToPostWithID:params[@"postID"]];
                return YES;
            }
        }
        
        // Do we know which thread the post comes from?
        AwfulPost *post = [AwfulPost firstMatchingPredicate:@"postID = %@", params[@"postID"]];
        if (post) {
            [self pushPostsViewForPostWithID:post.postID
                                      onPage:post.page
                              ofThreadWithID:post.thread.threadID];
            return YES;
        }
        
        // Go find the thread.
        [SVProgressHUD showWithStatus:@"Locating Post"];
        [[AwfulHTTPClient client] locatePostWithID:params[@"postID"]
                                           andThen:^(NSError *error, NSString *threadID,
                                                     AwfulThreadPage page)
        {
            if (error) {
                [SVProgressHUD showErrorWithStatus:@"Post Not Found"];
                NSLog(@"couldn't resolve post at %@: %@", params[kJLRouteURLKey], error);
            } else {
                [SVProgressHUD dismiss];
                [self pushPostsViewForPostWithID:params[@"postID"]
                                          onPage:page
                                  ofThreadWithID:threadID];
            }
        }];
        return YES;
    }];
    
    #pragma mark Legacy routes
    
    [JLRoutes addRoute:@"/favorites/:forumID" handler:^(NSDictionary *params) {
        jumpToForum(params[@"forumID"]);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/favorites" handler:^(NSDictionary *parameters) {
        UINavigationController *nav = self.tabBarController.viewControllers[0];
        self.tabBarController.selectedViewController = nav;
        UIScrollView *scrollView = (id)nav.topViewController.view;
        if ([scrollView respondsToSelector:@selector(setContentOffset:animated:)]) {
            [scrollView setContentOffset:CGPointMake(0, -scrollView.contentInset.top) animated:YES];
        }
        [self.splitViewController setSidebarVisible:YES animated:YES];
        return YES;
    }];
}

- (void)pushPostsViewForPostWithID:(NSString *)postID
                            onPage:(NSInteger)page
                    ofThreadWithID:(NSString *)threadID
{
    AwfulPostsViewController *postsView = [AwfulPostsViewController new];
    postsView.thread = [AwfulThread firstOrNewThreadWithThreadID:threadID];
    [postsView loadPage:page singleUserID:nil];
    [postsView jumpToPostWithID:postID];
    UINavigationController *nav;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        nav = (id)self.splitViewController.mainViewController;
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
    return [AwfulHTTPClient client].loggedIn;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if ([navigationController isEqual:self.splitViewController.mainViewController]) {
        [self ensureShowSidebarButtonInMainViewController];
    }
}

- (void)ensureShowSidebarButtonInMainViewController
{
    UINavigationController *nav = (id)self.splitViewController.mainViewController;
    UIViewController *bottom = nav.viewControllers[0];
    if (self.splitViewController.sidebarCanHide) {
        bottom.navigationItem.leftBarButtonItem = self.showSidebarButtonItem;
    } else {
        bottom.navigationItem.leftBarButtonItem = nil;
    }
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginController:(AwfulLoginController *)login
 didLogInAsUserWithInfo:(NSDictionary *)userInfo
{
    NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    [AwfulSettings settings].lastForcedUserInfoUpdateVersion = appVersion;
    [AwfulSettings settings].username = userInfo[@"username"];
    [AwfulSettings settings].userID = userInfo[@"userID"];
    [AwfulSettings settings].canSendPrivateMessages = [userInfo[@"canSendPrivateMessages"] boolValue];
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[AwfulHTTPClient client] listForumsAndThen:nil];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.splitViewController setSidebarVisible:YES animated:YES];
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

#pragma mark - AwfulSplitViewControllerDelegate

- (BOOL)awfulSplitViewController:(AwfulSplitViewController *)controller
  shouldHideSidebarInOrientation:(UIInterfaceOrientation)orientation
{
    switch ([AwfulSettings settings].keepSidebarOpen) {
        case AwfulKeepSidebarOpenAlways: return NO;
        case AwfulKeepSidebarOpenInLandscape: return UIInterfaceOrientationIsPortrait(orientation);
        case AwfulKeepSidebarOpenInPortrait: return UIInterfaceOrientationIsLandscape(orientation);
        case AwfulKeepSidebarOpenNever: default: return YES;
    }
}

- (void)awfulSplitViewController:(AwfulSplitViewController *)controller
                 willHideSidebar:(BOOL)willHideSidebar
{
    [self ensureShowSidebarButtonInMainViewController];
}

@end
