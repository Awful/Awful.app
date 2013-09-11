//  AwfulAppDelegate.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAppDelegate.h"
#import "AwfulAlertView.h"
#import "AwfulBasementViewController.h"
#import "AwfulBookmarksController.h"
#import "AwfulCrashlytics.h"
#import "AwfulDataStack.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLepersViewController.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulNavigationBar.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPostsViewController.h"
#import "AwfulPrivateMessageListController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulStartViewController.h"
#import "AwfulTheme.h"
#import "AwfulVerticalTabBarController.h"
#import <AFNetworking/AFNetworking.h>
#import <AVFoundation/AVFoundation.h>
#import <Crashlytics/Crashlytics.h>
#import <JLRoutes/JLRoutes.h>
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "NSURL+Awful.h"
#import "NSURL+Punycode.h"
#import <PocketAPI/PocketAPI.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIViewController+AwfulTheming.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulAppDelegate () <AwfulLoginControllerDelegate>

@property (strong, nonatomic) AwfulBasementViewController *basementViewController;
@property (strong, nonatomic) AwfulVerticalTabBarController *verticalTabBarController;

@end

@implementation AwfulAppDelegate

static id _instance;

+ (instancetype)instance
{
    return _instance;
}

- (void)showLoginFormIsAtLaunch:(BOOL)isAtLaunch andThen:(void (^)(void))callback
{
    AwfulLoginController *login = [AwfulLoginController new];
    login.delegate = self;
    BOOL animated = !isAtLaunch || UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    [self.window.rootViewController presentViewController:[login enclosingNavigationController]
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
    [[AwfulSettings settings] reset];
    
    // Clear any stored logins for other services
    [[PocketAPI sharedAPI] logout];
    
    // Delete cached post info. The next user might see things differently than the one logging out.
    // And this lets logging out double as a "delete all data" button.
    [[AwfulDataStack sharedDataStack] deleteAllDataAndResetStack];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulUserDidLogOutNotification
                                                        object:nil];
    
    [self showLoginFormIsAtLaunch:NO andThen:^{
        self.basementViewController.selectedIndex = 0;
        self.verticalTabBarController.selectedIndex = 0;
    }];
}

NSString * const AwfulUserDidLogOutNotification = @"com.awfulapp.Awful.UserDidLogOutNotification";

- (void)setUpRootViewController
{
    NSMutableArray *viewControllers = [@[ [[AwfulForumsListController new] enclosingNavigationController],
                                          [[AwfulBookmarksController new] enclosingNavigationController],
                                          [[AwfulLepersViewController new] enclosingNavigationController],
                                          [[AwfulSettingsViewController new] enclosingNavigationController] ] mutableCopy];
    if ([AwfulSettings settings].canSendPrivateMessages) {
        [viewControllers insertObject:[[AwfulPrivateMessageListController new] enclosingNavigationController]
                              atIndex:2];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.basementViewController = [[AwfulBasementViewController alloc] initWithViewControllers:viewControllers];
        self.window.rootViewController = self.basementViewController;
    } else {
        NSMutableArray *splits = [NSMutableArray new];
        for (UIViewController *viewController in viewControllers) {
            AwfulExpandingSplitViewController *split;
            split = [[AwfulExpandingSplitViewController alloc] initWithViewControllers:@[ viewController ]];
            [splits addObject:split];
        }
        self.verticalTabBarController = [[AwfulVerticalTabBarController alloc] initWithViewControllers:splits];
        self.window.rootViewController = self.verticalTabBarController;
    }
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
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:5 * 1024 * 1024
                                                                diskCapacity:50 * 1024 * 1024
                                                                    diskPath:nil]];
    
    [self ignoreSilentSwitchWhenPlayingEmbeddedVideo];
    
    application.statusBarStyle = UIStatusBarStyleLightContent;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.tintColor = [UIColor whiteColor];
    [self setUpRootViewController];
    
    [self routeAwfulURLs];
    
    [self.window makeKeyAndVisible];
        
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
        ok = [fileman removeItemAtURL:cssDestination error:&error];
        if (!ok && !([error.domain isEqualToString:NSCocoaErrorDomain] &&
                     error.code == NSFileNoSuchFileError)) {
            NSLog(@"error deleting example-posts-view.css: %@", error);
        }
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
    
    if (![AwfulHTTPClient client].loggedIn) {
        [self showLoginFormIsAtLaunch:YES andThen:nil];
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
    [noteCenter addObserver:self
                   selector:@selector(settingsDidChange:)
                       name:AwfulSettingsDidChangeNotification
                     object:nil];
    
    [[PocketAPI sharedAPI] setURLScheme:@"awful-pocket-login"];
    [[PocketAPI sharedAPI] setConsumerKey:@"13890-9e69d4d40af58edc2ef13ca0"];
    
    return YES;
}

- (void)themeDidChange:(NSNotification *)note
{
    [self.window.rootViewController recursivelyRetheme];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *changes = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([changes containsObject:AwfulSettingsKeys.canSendPrivateMessages]) {
        
        // Add the private message list if it's needed, or remove it if it isn't.
        NSArray *roots = [self rootViewControllersUncontained];
        NSUInteger i = [[roots valueForKey:@"class"] indexOfObject:[AwfulPrivateMessageListController class]];
        if ([AwfulSettings settings].canSendPrivateMessages) {
            if (i == NSNotFound) {
                UINavigationController *nav = [[AwfulPrivateMessageListController new] enclosingNavigationController];
                if (self.basementViewController) {
                    NSMutableArray *viewControllers = [self.basementViewController.viewControllers mutableCopy];
                    [viewControllers insertObject:nav atIndex:2];
                    self.basementViewController.viewControllers = viewControllers;
                } else if (self.verticalTabBarController) {
                    NSMutableArray *viewControllers = [self.verticalTabBarController.viewControllers mutableCopy];
                    [viewControllers insertObject:[[AwfulExpandingSplitViewController alloc] initWithViewControllers:@[ nav ]]
                                          atIndex:2];
                    self.verticalTabBarController.viewControllers = viewControllers;
                }
            }
        } else {
            if (i != NSNotFound) {
                if (self.basementViewController) {
                    NSMutableArray *viewControllers = [self.basementViewController.viewControllers mutableCopy];
                    [viewControllers removeObjectAtIndex:i];
                    self.basementViewController.viewControllers = viewControllers;
                } else if (self.verticalTabBarController) {
                    NSMutableArray *viewControllers = [self.verticalTabBarController.viewControllers mutableCopy];
                    [viewControllers removeObjectAtIndex:i];
                    self.verticalTabBarController.viewControllers = viewControllers;
                }
            }
        }
    }
}

- (NSArray *)rootViewControllersUncontained
{
    NSMutableArray *roots = [NSMutableArray new];
    for (UINavigationController *nav in self.basementViewController.viewControllers) {
        [roots addObject:nav.viewControllers[0]];
    }
    for (id something in self.verticalTabBarController.viewControllers) {
        UINavigationController *nav;
        if ([something isKindOfClass:[AwfulExpandingSplitViewController class]]) {
            nav = ((AwfulExpandingSplitViewController *)something).viewControllers[0];
        } else {
            nav = something;
        }
        [roots addObject:nav.viewControllers[0]];
    }
    return roots;
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
                     onAcceptance:^{ [self openAwfulURL:[url awfulURL]]; }];
}

#pragma mark - awful:// URL scheme

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if ([[PocketAPI sharedAPI] handleOpenURL:url]) return YES;
    if ([[url scheme] compare:@"awful" options:NSCaseInsensitiveSearch] != NSOrderedSame) return NO;
    if (![AwfulHTTPClient client].loggedIn) return NO;
    return [self openAwfulURL:url];
}

- (BOOL)openAwfulURL:(NSURL *)url
{
    return [JLRoutes routeURL:url];
}

- (void)routeAwfulURLs
{
    // TODO fix this for new iPhone, iPad root view controllers.
    AwfulBasementViewController *tabBar = self.basementViewController;
    void (^jumpToForum)(NSString *) = ^(NSString *forumID) {
        AwfulForum *forum = [AwfulForum fetchOrInsertForumWithID:forumID];
        UINavigationController *nav = tabBar.viewControllers[0];
        [self jumpToForum:forum inNavigationController:nav];
    };
    
    [JLRoutes addRoute:@"/forums/:forumID" handler:^(NSDictionary *params) {
        jumpToForum(params[@"forumID"]);
        return YES;
    }];
    
    [JLRoutes addRoute:@"/forums" handler:^(id _) {
        tabBar.selectedViewController = tabBar.viewControllers[0];
        return YES;
    }];
    
    void (^selectAndPopViewControllerAtIndex)(NSInteger) = ^(NSInteger i) {
        UINavigationController *nav = tabBar.viewControllers[i];
        [nav popToRootViewControllerAnimated:YES];
        tabBar.selectedViewController = nav;
    };
    
    // TODO messages has changed positions, and may not even appear if the user doesn't support PMs.
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
    
    BOOL (^openThread)(NSDictionary *) = ^(NSDictionary *params) {
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
        NSArray *maybes = tabBar.viewControllers;
        for (UINavigationController *nav in maybes) {
            AwfulPostsViewController *top = (id)nav.topViewController;
            if (![top isKindOfClass:[AwfulPostsViewController class]]) continue;
            if ([top.thread.threadID isEqual:params[@"threadID"]]) {
                if ((page == 0 || page == top.currentPage) &&
                    [top.singleUserID isEqualToString:params[@"userID"]]) {
                    if ([maybes count] > 1) {
                        tabBar.selectedViewController = nav;
                    }
                    return YES;
                }
            }
        }
        
        // Load the thread in a new posts view.
        AwfulPostsViewController *postsView = [AwfulPostsViewController new];
        postsView.thread = [AwfulThread firstOrNewThreadWithThreadID:params[@"threadID"]];
        if (page == 0) {
            page = 1;
        }
        [postsView loadPage:page singleUserID:params[@"userID"]];
        UINavigationController *nav = (id)tabBar.selectedViewController;
        
        // On iPad, the app launches with a tag collage as its detail view. A posts view needs to
        // replace this collage, not be pushed on top.
        [nav pushViewController:postsView animated:YES];
        
        return YES;
    };
    
    [JLRoutes addRoute:@"/threads/:threadID/pages/:page" handler:^(NSDictionary *params) {
        return openThread(params);
    }];
    
    [JLRoutes addRoute:@"/threads/:threadID" handler:^(NSDictionary *params) {
        return openThread(params);
    }];
    
    [JLRoutes addRoute:@"/posts/:postID" handler:^(NSDictionary *params) {
        // Maybe the post is already visible.
        NSArray *maybes = tabBar.viewControllers;
        for (UINavigationController *nav in maybes) {
            AwfulPostsViewController *top = (id)nav.topViewController;
            if (![top isKindOfClass:[AwfulPostsViewController class]]) continue;
            if ([[top.posts valueForKey:@"postID"] containsObject:params[@"postID"]]) {
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
        UINavigationController *nav = tabBar.viewControllers[0];
        tabBar.selectedViewController = nav;
        UIScrollView *scrollView = (id)nav.topViewController.view;
        if ([scrollView respondsToSelector:@selector(setContentOffset:animated:)]) {
            [scrollView setContentOffset:CGPointMake(0, -scrollView.contentInset.top) animated:YES];
        }
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
    UITabBarController *tabBar = (UITabBarController *)(self.basementViewController);
    nav = (UINavigationController *)tabBar.selectedViewController;
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
            UITabBarController *tabBar = (UITabBarController *)(self.basementViewController);
            tabBar.selectedViewController = nav;
            return;
        }
    }
    [nav popToRootViewControllerAnimated:NO];
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [nav pushViewController:threadList animated:YES];
    UITabBarController *tabBar = (UITabBarController *)(self.basementViewController);
    tabBar.selectedViewController = nav;
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginController:(AwfulLoginController *)login
 didLogInAsUserWithInfo:(NSDictionary *)userInfo
{
    NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    AwfulSettings *settings = [AwfulSettings settings];
    settings.lastForcedUserInfoUpdateVersion = appVersion;
    settings.username = userInfo[@"username"];
    settings.userID = userInfo[@"userID"];
    settings.canSendPrivateMessages = [userInfo[@"canSendPrivateMessages"] boolValue];
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[AwfulHTTPClient client] listForumsAndThen:nil];
    }];
}

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error
{
    [AwfulAlertView showWithTitle:@"Problem Logging In"
                          message:@"Double-check your username and password, then try again."
                      buttonTitle:@"Alright"
                       completion:nil];
}

@end
