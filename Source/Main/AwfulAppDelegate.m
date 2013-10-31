//  AwfulAppDelegate.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAppDelegate.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "AwfulAlertView.h"
#import "AwfulBasementViewController.h"
#import "AwfulBookmarkedThreadTableViewController.h"
#import "AwfulCrashlytics.h"
#import "AwfulDataStack.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLoginController.h"
#import "AwfulMinusFixURLProtocol.h"
#import "AwfulModels.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPrivateMessageTableViewController.h"
#import "AwfulRapSheetViewController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulThemeLoader.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import "AwfulURLRouter.h"
#import "AwfulVerticalTabBarController.h"
#import <AVFoundation/AVFoundation.h>
#import <Crashlytics/Crashlytics.h>
#import <PocketAPI/PocketAPI.h>

@interface AwfulAppDelegate () <AwfulLoginControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) AwfulBasementViewController *basementViewController;
@property (strong, nonatomic) AwfulVerticalTabBarController *verticalTabBarController;

@end

@implementation AwfulAppDelegate
{
    AwfulDataStack *_dataStack;
    AwfulURLRouter *_awfulURLRouter;
}

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
    [[AwfulHTTPClient client] reset];
    
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
    [_dataStack deleteStoreAndResetStack];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulUserDidLogOutNotification
                                                        object:nil];
    
    [self showLoginFormIsAtLaunch:NO andThen:^{
        self.basementViewController.selectedIndex = 0;
        self.verticalTabBarController.selectedIndex = 0;
    }];
}

NSString * const AwfulUserDidLogOutNotification = @"com.awfulapp.Awful.UserDidLogOutNotification";

- (NSManagedObjectContext *)managedObjectContext
{
    return _dataStack.managedObjectContext;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _instance = self;
    #if defined(CRASHLYTICS_API_KEY) && !DEBUG
        [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
    #endif
    [[AwfulSettings settings] registerDefaults];
    [[AwfulSettings settings] migrateOldSettings];
    
    NSURL *storeURL = [NSFileManager.defaultManager.documentDirectory URLByAppendingPathComponent:@"AwfulData.sqlite"];
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Awful" withExtension:@"momd"];
    _dataStack = [[AwfulDataStack alloc] initWithStoreURL:storeURL modelURL:modelURL];
    
    [AwfulHTTPClient client].managedObjectContext = _dataStack.managedObjectContext;
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:5 * 1024 * 1024
                                                                diskCapacity:50 * 1024 * 1024
                                                                    diskPath:nil]];
    [NSURLProtocol registerClass:[AwfulMinusFixURLProtocol class]];
    
    NSMutableArray *viewControllers = [NSMutableArray new];
    UINavigationController *nav;
    UIViewController *vc;
    
    vc = [[AwfulForumsListController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = ForumListControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = ForumNavigationControllerIdentifier;
    nav.restorationClass = nil;
    nav.delegate = self;
    [viewControllers addObject:nav];
    
    vc = [[AwfulBookmarkedThreadTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = BookmarksControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = BookmarksNavigationControllerIdentifier;
    nav.restorationClass = nil;
    nav.delegate = self;
    [viewControllers addObject:nav];
    
    if ([AwfulSettings settings].canSendPrivateMessages) {
        vc = [[AwfulPrivateMessageTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
        vc.restorationIdentifier = MessagesListControllerIdentifier;
        nav = [vc enclosingNavigationController];
        nav.restorationIdentifier = MessagesNavigationControllerIdentifier;
        nav.restorationClass = nil;
        nav.delegate = self;
        [viewControllers addObject:nav];
    }

    vc = [AwfulRapSheetViewController new];
    vc.restorationIdentifier = LepersColonyViewControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = LepersColonyNavigationControllerIdentifier;
    nav.restorationClass = nil;
    nav.delegate = self;
    [viewControllers addObject:nav];
    
    vc = [[AwfulSettingsViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = SettingsViewControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = SettingsNavigationControllerIdentifier;
    nav.restorationClass = nil;
    nav.delegate = self;
    [viewControllers addObject:nav];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.basementViewController = [[AwfulBasementViewController alloc] initWithViewControllers:viewControllers];
        self.basementViewController.restorationIdentifier = RootViewControllerIdentifier;
        self.window.rootViewController = self.basementViewController;
    } else {
        self.verticalTabBarController = [[AwfulVerticalTabBarController alloc] initWithViewControllers:viewControllers];
        self.verticalTabBarController.restorationIdentifier = RootViewControllerIdentifier;
        self.window.rootViewController = [[AwfulExpandingSplitViewController alloc] initWithViewControllers:@[ self.verticalTabBarController ]];
        self.window.rootViewController.restorationIdentifier = RootExpandingSplitViewControllerIdentifier;
    }
    [self themeDidChange];
    [self.window makeKeyAndVisible];
    return YES;
}

static NSString * const RootViewControllerIdentifier = @"AwfulRootViewController";
static NSString * const RootExpandingSplitViewControllerIdentifier = @"AwfulRootExpandingSplitViewController";

static NSString * const ForumListControllerIdentifier = @"AwfulForumListController";
static NSString * const BookmarksControllerIdentifier = @"AwfulBookmarksController";
static NSString * const MessagesListControllerIdentifier = @"AwfulPrivateMessagesListController";
static NSString * const LepersColonyViewControllerIdentifier = @"AwfulLepersColonyViewController";
static NSString * const SettingsViewControllerIdentifier = @"AwfulSettingsViewController";

static NSString * const ForumNavigationControllerIdentifier = @"AwfulForumNavigationController";
static NSString * const BookmarksNavigationControllerIdentifier = @"AwfulBookmarksNavigationController";
static NSString * const MessagesNavigationControllerIdentifier = @"AwfulMessagesNavigationController";
static NSString * const LepersColonyNavigationControllerIdentifier = @"AwfulLepersColonyNavigationController";
static NSString * const SettingsNavigationControllerIdentifier = @"AwfulSettingsNavigationController";

- (void)themeDidChange
{
    self.window.tintColor = AwfulTheme.currentTheme[@"tintColor"];
	[self.window.rootViewController themeDidChange];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self ignoreSilentSwitchWhenPlayingEmbeddedVideo];
    
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    
    _awfulURLRouter = [[AwfulURLRouter alloc] initWithRootViewController:self.window.rootViewController
                                                    managedObjectContext:_dataStack.managedObjectContext];
    
    [[PocketAPI sharedAPI] setURLScheme:@"awful-pocket-login"];
    [[PocketAPI sharedAPI] setConsumerKey:@"13890-9e69d4d40af58edc2ef13ca0"];
    
    return YES;
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *changes = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([changes containsObject:AwfulSettingsKeys.canSendPrivateMessages]) {
        
        // Add the private message list if it's needed, or remove it if it isn't.
        NSMutableArray *roots = [(self.basementViewController ?: self.verticalTabBarController) mutableArrayValueForKey:@"viewControllers"];
        NSUInteger i = [roots indexOfObjectPassingTest:^(UINavigationController *nav, NSUInteger i, BOOL *stop) {
            return [nav.viewControllers.firstObject isKindOfClass:[AwfulPrivateMessageTableViewController class]];
        }];
        if ([AwfulSettings settings].canSendPrivateMessages) {
            if (i == NSNotFound) {
                UINavigationController *nav = [[[AwfulPrivateMessageTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext] enclosingNavigationController];
                [roots insertObject:nav atIndex:2];
            }
        } else {
            if (i != NSNotFound) {
                [roots removeObjectAtIndex:i];
            }
        }
    }
    
	for (NSString *change in changes) {
		if ([change isEqualToString:AwfulSettingsKeys.darkTheme] || [change hasPrefix:@"theme"]) {
			
			// When the user initiates a theme change, transition from one theme to the other with a full-screen screenshot fading into the reconfigured interface.
			UIView *snapshot = [self.window snapshotViewAfterScreenUpdates:NO];
			[self.window addSubview:snapshot];
			[self themeDidChange];
			[UIView transitionFromView:snapshot
                                toView:nil
                              duration:0.2
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            completion:^(BOOL finished)
            {
				[snapshot removeFromSuperview];
			}];
            break;
		}
	}
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[AwfulNewPMNotifierAgent agent] checkForNewMessages];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSError *error;
    BOOL ok = [_dataStack.managedObjectContext save:&error];
    if (!ok) {
        NSLog(@"%s error saving main managed object context: %@", __PRETTY_FUNCTION__, error);
    }
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
    if (![url awfulURL] || [[url scheme] compare:@"awful" options:NSCaseInsensitiveSearch] == NSOrderedSame) return;
    
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

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return [AwfulHTTPClient client].isLoggedIn;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:0 forKey:InterfaceVersionKey];
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    NSNumber *userInterfaceIdiom = [coder decodeObjectForKey:UIApplicationStateRestorationUserInterfaceIdiomKey];
    return userInterfaceIdiom.integerValue == UI_USER_INTERFACE_IDIOM() && [AwfulHTTPClient client].loggedIn;
}

- (UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    return ViewControllerWithRestorationIdentifier(self.window.rootViewController, identifierComponents.lastObject);
}

static UIViewController * ViewControllerWithRestorationIdentifier(UIViewController *viewController, NSString *identifier)
{
    if ([viewController.restorationIdentifier isEqualToString:identifier]) return viewController;
    if (![viewController respondsToSelector:@selector(viewControllers)]) return nil;
    for (UIViewController *child in [viewController valueForKey:@"viewControllers"]) {
        UIViewController *found = ViewControllerWithRestorationIdentifier(child, identifier);
        if (found) return found;
    }
    return nil;
}

/**
 * Incremented whenever the state-preservable/restorable user interface changes so restoration code can migrate old saved state.
 */
static NSString * const InterfaceVersionKey = @"AwfulInterfaceVersion";

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if (!AwfulHTTPClient.client.loggedIn) return NO;
    if ([self openAwfulURL:url]) return YES;
    return [PocketAPI.sharedAPI handleOpenURL:url];
}

- (BOOL)openAwfulURL:(NSURL *)url
{
    return [_awfulURLRouter routeURL:url];
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

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [navigationController setToolbarHidden:(viewController.toolbarItems.count == 0) animated:animated];
}

@end
