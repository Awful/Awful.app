//  AwfulAppDelegate.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAppDelegate.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import <AVFoundation/AVFoundation.h>
#import "AwfulAlertView.h"
#import "AwfulAvatarLoader.h"
#import "AwfulBasementViewController.h"
#import "AwfulBookmarkedThreadTableViewController.h"
#import "AwfulCrashlytics.h"
#import "AwfulDataStack.h"
#import "AwfulEmptyViewController.h"
#import "AwfulForumsClient.h"
#import "AwfulForumsListController.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulImageURLProtocol.h"
#import "AwfulLaunchImageViewController.h"
#import "AwfulLoginController.h"
#import "AwfulMinusFixURLProtocol.h"
#import "AwfulModels.h"
#import "AwfulNavigationController.h"
#import "AwfulNewMessageChecker.h"
#import "AwfulPostsViewExternalStylesheetLoader.h"
#import "AwfulPrivateMessageTableViewController.h"
#import "AwfulRapSheetViewController.h"
#import "AwfulResourceURLProtocol.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulSplitViewController.h"
#import "AwfulThemeLoader.h"
#import "AwfulUnpoppingViewHandler.h"
#import "AwfulURLRouter.h"
#import "AwfulVerticalTabBarController.h"
#import "AwfulWaffleimagesURLProtocol.h"
#import <Crashlytics/Crashlytics.h>
#import <GRMustache/GRMustache.h>
#import <PocketAPI/PocketAPI.h>

@interface AwfulAppDelegate () <AwfulLoginControllerDelegate>

@property (strong, nonatomic) AwfulBasementViewController *basementViewController;
@property (strong, nonatomic) AwfulVerticalTabBarController *verticalTabBarController;
@property (strong, nonatomic) AwfulSplitViewController *splitViewController;

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

- (void)logOut
{
    // Destroy root view controller before deleting data store so there's no lingering references to persistent objects or their controllers.
    [self destroyRootViewControllerStack];
    
    // Reset the HTTP client so it gets remade (if necessary) with the default URL.
    [[AwfulForumsClient client] reset];
    
    // Logging out doubles as an "empty cache" button.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[AwfulSettings settings] reset];
    [[PocketAPI sharedAPI] logout];
    [[AwfulAvatarLoader loader] emptyCache];
    
    [UIView transitionWithView:self.window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^
    {
        [UIView performWithoutAnimation:^{
            self.window.rootViewController = [AwfulLaunchImageViewController new];
        }];
    } completion:^(BOOL finished) {
        AwfulLoginController *loginController = [AwfulLoginController new];
        loginController.delegate = self;
        [self.window.rootViewController presentViewController:[loginController enclosingNavigationController] animated:YES completion:nil];
        
        // If we delete the store earlier, the root view controller's still hanging around in an autorelease pool somewhere. If a posts view was open when logging out (which can happen on iPad), it'll crash when the store disappears out from under the managed object context. This seems like a reasonable time to delete the store, as it's not like anyone can do anything in the meantime.
        [_dataStack deleteStoreAndResetStack];
    }];
}

- (NSManagedObjectContext *)managedObjectContext
{
    return _dataStack.managedObjectContext;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    StartCrashlytics();
    _instance = self;
    [[AwfulSettings settings] registerDefaults];
    [[AwfulSettings settings] migrateOldSettings];
    
    SetCrashlyticsUsername();
    
    [GRMustache preventNSUndefinedKeyExceptionAttack];
    
    NSURL *oldStoreURL = [[[NSFileManager defaultManager] documentDirectory] URLByAppendingPathComponent:@"AwfulData.sqlite"];
    NSURL *storeURL = [[[NSFileManager defaultManager] cachesDirectory] URLByAppendingPathComponent:@"AwfulData.sqlite"];
    if (!MoveDataStore(oldStoreURL, storeURL)) {
        DeleteDataStoreAtURL(oldStoreURL);
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Awful" withExtension:@"momd"];
    _dataStack = [[AwfulDataStack alloc] initWithStoreURL:storeURL modelURL:modelURL];
    
    [AwfulForumsClient client].managedObjectContext = _dataStack.managedObjectContext;
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:5 * 1024 * 1024
                                                                diskCapacity:50 * 1024 * 1024
                                                                    diskPath:nil]];
    [NSURLProtocol registerClass:[AwfulImageURLProtocol class]];
    [NSURLProtocol registerClass:[AwfulMinusFixURLProtocol class]];
    [NSURLProtocol registerClass:[AwfulResourceURLProtocol class]];
    [NSURLProtocol registerClass:[AwfulWaffleimagesURLProtocol class]];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.tintColor = [AwfulTheme currentTheme][@"tintColor"];
    if ([AwfulForumsClient client].loggedIn) {
        self.window.rootViewController = [self createRootViewControllerStack];
    } else {
        self.window.rootViewController = [AwfulLaunchImageViewController new];
    }
    [self.window makeKeyAndVisible];
    return YES;
}

#define CRASHLYTICS_ENABLED defined(CRASHLYTICS_API_KEY) && !DEBUG

static inline void StartCrashlytics(void)
{
    #if CRASHLYTICS_ENABLED
        [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
        SetCrashlyticsUsername();
    #endif
}

static inline void SetCrashlyticsUsername(void)
{
    #if CRASHLYTICS_ENABLED && AWFUL_BETA
        [Crashlytics setUserName:[AwfulSettings settings].username];
    #endif
}

- (UIViewController *)createRootViewControllerStack
{
    NSMutableArray *viewControllers = [NSMutableArray new];
    UINavigationController *nav;
    UIViewController *vc;
    
    vc = [[AwfulForumsListController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = ForumListControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = ForumNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    vc = [[AwfulBookmarkedThreadTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = BookmarksControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = BookmarksNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    if ([AwfulSettings settings].canSendPrivateMessages) {
        vc = [[AwfulPrivateMessageTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
        vc.restorationIdentifier = MessagesListControllerIdentifier;
        nav = [vc enclosingNavigationController];
        nav.restorationIdentifier = MessagesNavigationControllerIdentifier;
        [viewControllers addObject:nav];
    }

    vc = [AwfulRapSheetViewController new];
    vc.restorationIdentifier = LepersColonyViewControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = LepersColonyNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    vc = [[AwfulSettingsViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = SettingsViewControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = SettingsNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    [viewControllers makeObjectsPerformSelector:@selector(setRestorationClass:) withObject:nil];
    
    UIViewController *rootViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.basementViewController = [[AwfulBasementViewController alloc] initWithViewControllers:viewControllers];
        self.basementViewController.restorationIdentifier = RootViewControllerIdentifier;
        rootViewController = self.basementViewController;
    } else {
        self.verticalTabBarController = [[AwfulVerticalTabBarController alloc] initWithViewControllers:viewControllers];
        self.verticalTabBarController.restorationIdentifier = RootViewControllerIdentifier;
        self.splitViewController = [AwfulSplitViewController new];
        AwfulEmptyViewController *emptyViewController = [AwfulEmptyViewController new];
        UINavigationController *detailViewController = [emptyViewController enclosingNavigationController];
        self.splitViewController.viewControllers = @[ self.verticalTabBarController, detailViewController ];
        self.splitViewController.restorationIdentifier = RootExpandingSplitViewControllerIdentifier;
        [self configureSplitViewControllerSettings];
        rootViewController = self.splitViewController;
    }
    
    _awfulURLRouter = [[AwfulURLRouter alloc] initWithRootViewController:rootViewController
                                                    managedObjectContext:_dataStack.managedObjectContext];
    return rootViewController;
}

- (void)destroyRootViewControllerStack
{
    self.basementViewController = nil;
    self.verticalTabBarController = nil;
    self.splitViewController = nil;
    self.window.rootViewController = nil;
    _awfulURLRouter = nil;
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

NSString * const AwfulDidEnterBackgroundNotification = @"com.awfulapp.Awful.EnterBackground";

- (void)themeDidChange
{
    self.window.tintColor = AwfulTheme.currentTheme[@"tintColor"];
	[self.window.rootViewController themeDidChange];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (![AwfulForumsClient client].loggedIn) {
        AwfulLoginController *login = [AwfulLoginController new];
        login.delegate = self;
        [self.window.rootViewController presentViewController:[login enclosingNavigationController] animated:NO completion:nil];
    }
    
    [self ignoreSilentSwitchWhenPlayingEmbeddedVideo];

    [self showPromptIfLoginCookieExpiresSoon];
    
    [[AwfulNewMessageChecker checker] refreshIfNecessary];
    
    [[AwfulPostsViewExternalStylesheetLoader loader] refreshIfNecessary];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    [[PocketAPI sharedAPI] setURLScheme:@"awful-pocket-login"];
    [[PocketAPI sharedAPI] setConsumerKey:@"13890-9e69d4d40af58edc2ef13ca0"];
    
    return YES;
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSString *setting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([setting isEqualToString:AwfulSettingsKeys.canSendPrivateMessages]) {
        
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
    } else if ([setting isEqualToString:AwfulSettingsKeys.username]) {
        SetCrashlyticsUsername();
    } else if ([setting isEqualToString:AwfulSettingsKeys.hideSidebarInLandscape]) {
        [self configureSplitViewControllerSettings];
    } else if ([setting isEqualToString:AwfulSettingsKeys.darkTheme] || [setting hasPrefix:@"theme"]) {
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
	}
}

- (void)preferredContentSizeDidChange:(NSNotification *)note
{
    [self themeDidChange];
}

- (void)configureSplitViewControllerSettings
{
    UIInterfaceOrientationMask mask = [AwfulSettings settings].hideSidebarInLandscape ? 0 : UIInterfaceOrientationMaskLandscape;
    self.splitViewController.stickySidebarInterfaceOrientationMask = mask;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSError *error;
    BOOL ok = [_dataStack.managedObjectContext save:&error];
    if (!ok) {
        NSLog(@"%s error saving main managed object context: %@", __PRETTY_FUNCTION__, error);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulDidEnterBackgroundNotification
                                                        object:self];
}

- (void)ignoreSilentSwitchWhenPlayingEmbeddedVideo
{
    NSError *error;
    BOOL ok = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!ok) {
        NSLog(@"error setting shared audio session category: %@", error);
    }
}


static NSString * const kLastExpiringCookiePromptDate = @"com.awfulapp.Awful.LastCookieExpiringPromptDate";
static const NSTimeInterval kCookieExpiringSoonThreshold = 60 * 60 * 24 * 7; // One week
static const NSTimeInterval kCookieExpiryPromptFrequency = 60 * 60 * 24 * 2; // 48 Hours

- (void)showPromptIfLoginCookieExpiresSoon
{
    NSDate *loginCookieExpiryDate = [AwfulForumsClient client].loginCookieExpiryDate;
    if (loginCookieExpiryDate && [loginCookieExpiryDate timeIntervalSinceNow] < kCookieExpiringSoonThreshold) {
        NSDate *lastPromptDate = [[NSUserDefaults standardUserDefaults] objectForKey:kLastExpiringCookiePromptDate];
        if (!lastPromptDate || [lastPromptDate timeIntervalSinceNow] > kCookieExpiryPromptFrequency) {

            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            NSString *dateString = [dateFormatter stringFromDate:loginCookieExpiryDate];
            NSString *message = [NSString stringWithFormat:@"Your login cookie expires on %@", dateString];

            [AwfulAlertView showWithTitle:@"Login Expiring Soon"
                                  message:message
                              buttonTitle:@"OK"
                               completion:^{
                                   [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastExpiringCookiePromptDate];
                               }];
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (![AwfulForumsClient client].loggedIn) return;
    
    NSURL *URL = [UIPasteboard generalPasteboard].awful_URL;
    
    // If it's not a URL we can handle, or if we specifically handle it some other way, stop here.
    if (!URL.awfulURL) return;
    NSArray *URLTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSArray *URLSchemes = [URLTypes valueForKeyPath:@"@distinctUnionOfArrays.CFBundleURLSchemes"];
    for (NSString *scheme in URLSchemes) {
        if ([URL.scheme caseInsensitiveCompare:scheme] == NSOrderedSame) return;
    }
    
    // Don't ask about the same URL over and over.
    if ([[AwfulSettings settings].lastOfferedPasteboardURL isEqualToString:URL.absoluteString]) {
        return;
    }
    [AwfulSettings settings].lastOfferedPasteboardURL = URL.absoluteString;
    
    NSMutableString *abbreviatedURL = [URL.awful_absoluteUnicodeString mutableCopy];
    NSRange upToHost = [abbreviatedURL rangeOfString:@"://"];
    if (upToHost.location == NSNotFound) {
        upToHost = [abbreviatedURL rangeOfString:@":"];
    }
    if (upToHost.location != NSNotFound) {
        upToHost.length += upToHost.location;
        upToHost.location = 0;
        [abbreviatedURL deleteCharactersInRange:upToHost];
    }
    if (abbreviatedURL.length > 60) {
        [abbreviatedURL replaceCharactersInRange:NSMakeRange(55, abbreviatedURL.length - 55) withString:@"…"];
    }
    NSString *message = [NSString stringWithFormat:@"Would you like to open this URL in Awful?\n\n%@", abbreviatedURL];
    [AwfulAlertView showWithTitle:@"Open in Awful"
                          message:message
                    noButtonTitle:@"Cancel"
                   yesButtonTitle:@"Open"
                     onAcceptance:^{ [self openAwfulURL:URL.awfulURL]; }];
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return [AwfulForumsClient client].loggedIn;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:0 forKey:InterfaceVersionKey];
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    NSNumber *userInterfaceIdiom = [coder decodeObjectForKey:UIApplicationStateRestorationUserInterfaceIdiomKey];
    return userInterfaceIdiom.integerValue == UI_USER_INTERFACE_IDIOM() && [AwfulForumsClient client].loggedIn;
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
            openURL:(NSURL *)URL
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if (![AwfulForumsClient client].loggedIn) return NO;
    if ([URL.scheme caseInsensitiveCompare:@"awfulhttp"] == NSOrderedSame) {
        return [self openAwfulURL:URL.awfulURL];
    }
    return [self openAwfulURL:URL] || [[PocketAPI sharedAPI] handleOpenURL:URL];
}

- (BOOL)openAwfulURL:(NSURL *)url
{
    return [_awfulURLRouter routeURL:url];
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginController:(AwfulLoginController *)login
         didLogInAsUser:(AwfulUser *)user
{
    AwfulSettings *settings = [AwfulSettings settings];
    settings.username = user.username;
    settings.userID = user.userID;
    settings.canSendPrivateMessages = user.canReceivePrivateMessages;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulUserDidLogInNotification object:user];
    
    [[AwfulForumsClient client] taxonomizeForumsAndThen:nil];
    [UIView transitionWithView:self.window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [UIView performWithoutAnimation:^{
                            [login dismissViewControllerAnimated:NO completion:nil];
                            self.window.rootViewController = [self createRootViewControllerStack];;
                        }];
                    } completion:nil];
}

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error
{
    [AwfulAlertView showWithTitle:@"Problem Logging In"
                          message:@"Double-check your username and password, then try again."
                      buttonTitle:@"OK"
                       completion:nil];
}

@end
