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

@interface AwfulAppDelegate ()

@property (strong, nonatomic) RootViewControllerStack *rootViewControllerStack;
@property (strong, nonatomic) LoginViewController *loginViewController;

@property (strong, nonatomic) AwfulDataStack *dataStack;
@property (strong, nonatomic) AwfulURLRouter *URLRouter;

@end

@implementation AwfulAppDelegate

static id _instance;

+ (instancetype)instance
{
    return _instance;
}

- (void)setRootViewController:(UIViewController *)rootViewController animated:(BOOL)animated completion:(void (^)(void))completionBlock
{
    [UIView transitionWithView:self.window
                      duration:animated ? 0.3 : 0
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^
     {
         self.window.rootViewController = rootViewController;
     } completion:^(BOOL completed){
         if (completionBlock) completionBlock();
     }];
}

- (NSManagedObjectContext *)managedObjectContext
{
    return _dataStack.managedObjectContext;
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
        _URLRouter = [[AwfulURLRouter alloc] initWithRootViewController:self.window.rootViewController
                                                   managedObjectContext:_dataStack.managedObjectContext];
    }
    return _rootViewControllerStack;
}

- (LoginViewController *)loginViewController
{
    if (!_loginViewController) {
        _loginViewController = [LoginViewController newFromStoryboard];
        __weak __typeof__(self) weakSelf = self;
        _loginViewController.completionBlock = ^(LoginViewController *login) {
            __typeof__(self) self = weakSelf;
            [self setRootViewController:self.rootViewControllerStack.rootViewController animated:YES completion:^{
                __typeof__(self) self = weakSelf;
                [self.rootViewControllerStack didAppear];
                self.loginViewController = nil;
            }];
        };
    }
    return _loginViewController;
}

- (void)themeDidChange
{
    self.window.tintColor = [AwfulTheme currentTheme][@"tintColor"];
    [self.window.rootViewController themeDidChange];
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

- (BOOL)openAwfulURL:(NSURL *)url
{
    return [self.URLRouter routeURL:url];
}

- (void)logOut
{
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
    
    __weak __typeof__(self) weakSelf = self;
    [self setRootViewController:[self.loginViewController enclosingNavigationController] animated:YES completion:^{
        __typeof__(self) self = weakSelf;
        self.rootViewControllerStack = nil;
        self.URLRouter = nil;
        [self.dataStack deleteStoreAndResetStack];
    }];
}

#pragma mark - UIApplicationDelegate

#pragma mark Launching and backgrounding

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
    
    application.statusBarStyle = UIStatusBarStyleLightContent;
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.tintColor = [AwfulTheme currentTheme][@"tintColor"];
    if ([AwfulForumsClient client].loggedIn) {
        [self setRootViewController:self.rootViewControllerStack.rootViewController animated:NO completion:nil];
    } else {
        [self setRootViewController:[self.loginViewController enclosingNavigationController] animated:NO completion:nil];
    }
    [self.window makeKeyAndVisible];
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Direct ivar access because we don't want to lazily create it now.
    [_rootViewControllerStack didAppear];
    
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

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSError *error;
    BOOL ok = [_dataStack.managedObjectContext save:&error];
    if (!ok) {
        NSLog(@"%s error saving main managed object context: %@", __PRETTY_FUNCTION__, error);
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

#pragma mark State preservation and restoration

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

#pragma mark URLs

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

@end
