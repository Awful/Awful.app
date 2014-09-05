//  AwfulAppDelegate.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAppDelegate.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import <AVFoundation/AVFoundation.h>
#import "AwfulAvatarLoader.h"
#import "AwfulCrashlytics.h"
#import "AwfulDataStack.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulImageURLProtocol.h"
#import "AwfulLaunchImageViewController.h"
#import "AwfulLoginController.h"
#import "AwfulMinusFixURLProtocol.h"
#import "AwfulModels.h"
#import "AwfulNewMessageChecker.h"
#import "AwfulPostsViewExternalStylesheetLoader.h"
#import "AwfulResourceURLProtocol.h"
#import "AwfulSettings.h"
#import "AwfulThemeLoader.h"
#import "AwfulURLRouter.h"
#import "AwfulWaffleimagesURLProtocol.h"
#import <Crashlytics/Crashlytics.h>
#import <GRMustache/GRMustache.h>
#import "Awful-Swift.h"

@interface AwfulAppDelegate () <AwfulLoginControllerDelegate>

@property (strong, nonatomic) RootViewControllerStack *rootViewControllerStack;

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
    [[AwfulSettings sharedSettings] reset];
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

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    StartCrashlytics();
    _instance = self;
    [[AwfulSettings sharedSettings] registerDefaults];
    [[AwfulSettings sharedSettings] migrateOldSettings];
    
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
        [Crashlytics setUserName:[AwfulSettings sharedSettings].username];
    #endif
}

- (RootViewControllerStack *)rootViewControllerStack
{
    if (!_rootViewControllerStack) {
        _rootViewControllerStack = [[RootViewControllerStack alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    }
    return _rootViewControllerStack;
}

- (UIViewController *)createRootViewControllerStack
{
    _awfulURLRouter = [[AwfulURLRouter alloc] initWithRootViewController:self.rootViewControllerStack.rootViewController
                                                    managedObjectContext:_dataStack.managedObjectContext];
    return self.rootViewControllerStack.rootViewController;
}

- (void)destroyRootViewControllerStack
{
    self.rootViewControllerStack = nil;
    self.window.rootViewController = nil;
    _awfulURLRouter = nil;
}

static NSString * const SplitViewControllerIdentifier = @"Root splitview";
static NSString * const TabBarControllerIdentifier = @"Primary tabbar";

static NSString * const ForumListIdentifier = @"Forum list";
static NSString * const BookmarksIdentifier = @"Bookmarks";
static NSString * const MessagesListIdentifier = @"Messages list";
static NSString * const LepersColonyIdentifier = @"Leper's Colony";
static NSString * const SettingsIdentifier = @"Settings";

static NSString * const ForumListNavigationIdentifier = @"Forum list navigation";
static NSString * const BookmarksNavigationIdentifier = @"Bookmarks navigation";
static NSString * const MessagesListNavigationIdentifier = @"Messages list navigation";
static NSString * const LepersColonyNavigationIdentifier = @"Leper's Colony navigation";
static NSString * const SettingsNavigationIdentifier = @"Settings navigation";
static NSString * const DetailNavigationIdentifier = @"Detail navigation";

- (void)themeDidChange
{
    self.window.tintColor = [AwfulTheme currentTheme][@"tintColor"];
	[self.window.rootViewController themeDidChange];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    application.statusBarStyle = UIStatusBarStyleLightContent;
    
    if (![AwfulForumsClient client].loggedIn) {
        AwfulLoginController *login = [AwfulLoginController new];
        login.delegate = self;
        [self.window.rootViewController presentViewController:[login enclosingNavigationController] animated:NO completion:nil];
    }
    
    [self.rootViewControllerStack didAppear];
    
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
    return YES;
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSString *setting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([setting isEqualToString:AwfulSettingsKeys.username]) {
        SetCrashlyticsUsername();
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

            UIAlertController *alert = [UIAlertController informationalAlertWithTitle:@"Login Expiring Soon" message:message handler:^(UIAlertAction *action) {
                [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastExpiringCookiePromptDate];
            }];
            [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
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
    if ([[AwfulSettings sharedSettings].lastOfferedPasteboardURL isEqualToString:URL.absoluteString]) {
        return;
    }
    [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
    
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Open in Awful" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openAwfulURL:URL.awfulURL];
    }]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - State preservation and restoration

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return [AwfulForumsClient client].loggedIn;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:CurrentInterfaceVersion forKey:InterfaceVersionKey];
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    if (![AwfulForumsClient client].loggedIn) return NO;
    AwfulInterfaceVersion interfaceVersion = [coder decodeIntegerForKey:InterfaceVersionKey];
    return interfaceVersion == CurrentInterfaceVersion;
}

- (UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    return [self.rootViewControllerStack viewControllerWithRestorationIdentifierPath:identifierComponents];
}

/**
 * An NSNumber containing an AwfulInterfaceVersion. Encoded when preserving state, and possibly useful for determining whether to decode state or to somehow migrate the preserved state.
 */
static NSString * const InterfaceVersionKey = @"AwfulInterfaceVersion";

/**
 * Historic Awful interface versions.
 */
typedef NS_ENUM(NSInteger, AwfulInterfaceVersion)
{
    /**
     * Interface for Awful 2, the version that runs on iOS 7. On iPhone, a basement-style menu is the root view controller. On iPad, a custom split view controller is the root view controller, and it hosts a vertical tab bar controller as its primary view controller.
     */
    AwfulInterfaceVersion2,
    
    /**
     * Interface for Awful 3, the version that runs on iOS 8. The primary view controller is a UITabBarController, which is hosted in a custom split view controller on iPad.
     */
    AwfulInterfaceVersion3,
};

static AwfulInterfaceVersion CurrentInterfaceVersion = AwfulInterfaceVersion3;

#pragma mark -

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if (![AwfulForumsClient client].loggedIn) return NO;
    if ([URL.scheme caseInsensitiveCompare:@"awfulhttp"] == NSOrderedSame) {
        return [self openAwfulURL:URL.awfulURL];
    }
    return [self openAwfulURL:URL];
}

- (BOOL)openAwfulURL:(NSURL *)url
{
    return [_awfulURLRouter routeURL:url];
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginController:(AwfulLoginController *)login
         didLogInAsUser:(AwfulUser *)user
{
    AwfulSettings *settings = [AwfulSettings sharedSettings];
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
    UIAlertController *alert = [UIAlertController informationalAlertWithTitle:@"Problem Logging In"
                                                                      message:@"Double-check your username and password, then try again."];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
