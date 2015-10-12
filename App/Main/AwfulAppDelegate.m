//  AwfulAppDelegate.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAppDelegate.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
@import AVFoundation;
#import "AwfulAvatarLoader.h"
@import AwfulCore;
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulImageURLProtocol.h"
#import "AwfulMinusFixURLProtocol.h"
#import "AwfulPostsViewExternalStylesheetLoader.h"
#import "AwfulSettings.h"
#import "AwfulURLRouter.h"
#import "AwfulWaffleimagesURLProtocol.h"
#import <GRMustache/GRMustache.h>
#import "NewMessageChecker.h"
@import Smilies;
#import "Awful-Swift.h"

@interface AwfulAppDelegate ()

@property (strong, nonatomic) RootViewControllerStack *rootViewControllerStack;
@property (strong, nonatomic) LoginViewController *loginViewController;

@property (strong, nonatomic) DataStore *dataStore;
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
    return self.dataStore.mainManagedObjectContext;
}

- (RootViewControllerStack *)rootViewControllerStack
{
    if (!_rootViewControllerStack) {
        _rootViewControllerStack = [[RootViewControllerStack alloc] initWithManagedObjectContext:self.managedObjectContext];
        _URLRouter = [[AwfulURLRouter alloc] initWithRootViewController:_rootViewControllerStack.rootViewController
                                                   managedObjectContext:self.managedObjectContext];
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
    self.window.tintColor = [Theme currentTheme][@"tintColor"];
    [self.window.rootViewController themeDidChange];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSString *setting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([setting isEqualToString:AwfulSettingsKeys.darkTheme] || [setting hasPrefix:@"theme"]) {
        // When the user initiates a theme change, transition from one theme to the other with a full-screen screenshot fading into the reconfigured interface.
        UIView *snapshot = [self.window snapshotViewAfterScreenUpdates:NO];
        [self.window addSubview:snapshot];
        [self themeDidChange];
        [UIView transitionFromView:snapshot
                            toView:self.window
                          duration:0.2
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionShowHideTransitionViews
                        completion:^(BOOL finished)
         {
             [snapshot removeFromSuperview];
         }];
    } else if ([setting isEqualToString:AwfulSettingsKeys.customBaseURL]) {
        [self updateClientBaseURL];
    }
}

- (void)updateClientBaseURL
{
    NSString *URLString = [AwfulSettings sharedSettings].customBaseURL ?: @"http://forums.somethingawful.com";
    NSURLComponents *components = [NSURLComponents componentsWithString:URLString];
    if (components.scheme.length == 0) {
        components.scheme = @"http";
    }
    
    // Bare IP address is parsed by NSURLComponents as a path.
    if (!components.host && components.path) {
        components.host = components.path;
        components.path = nil;
    }
    
    [AwfulForumsClient sharedClient].baseURL = components.URL;
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
            
            UIAlertController *alert = [[UIAlertController alloc] initAlertWithTitle:@"Login Expiring Soon" message:message handler:^(UIAlertAction *action) {
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
    // Logging out doubles as an "empty cache" button.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[AwfulSettings sharedSettings] reset];
    [[AwfulAvatarLoader loader] emptyCache];
    
    // Do this after resetting settings so that it gets the default baseURL.
    [self updateClientBaseURL];
    
    __weak __typeof__(self) weakSelf = self;
    [self setRootViewController:[self.loginViewController enclosingNavigationController] animated:YES completion:^{
        __typeof__(self) self = weakSelf;
        self.rootViewControllerStack = nil;
        self.URLRouter = nil;
        [self.dataStore deleteStoreAndReset];
    }];
}

static void RemoveOldDataStores(void)
{
    // Obsolete data stores should be cleaned up so we're not wasting space.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *pendingDeletions = [NSMutableArray new];
    
    // The Documents directory is pre-Awful 3.0. It was unsuitable because it was not user-managed data.
    // The Caches directory was used through Awful 3.1. It was unsuitable once user data was stored in addition to cached presentation data.
    // Both stores were under the same filename.
    NSArray *directories = @[fileManager.documentDirectory, fileManager.cachesDirectory];
    NSString *oldStoreFilename = @"AwfulData.sqlite";
    
    for (NSURL *directory in directories) {
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directory includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:^BOOL(NSURL *URL, NSError *error) {
            NSLog(@"%s error enumerating URL %@: %@", __PRETTY_FUNCTION__, URL, error);
            return YES;
        }];
        for (NSURL *URL in enumerator) {
            // Check for prefix, not equality, as there could be associated files (SQLite indexes or logs) that should also disappear.
            if ([URL.lastPathComponent hasPrefix:oldStoreFilename]) {
                [pendingDeletions addObject:URL];
            }
        }
    }
    
    for (NSURL *URL in pendingDeletions) {
        NSError *error;
        if (![fileManager removeItemAtURL:URL error:&error]) {
            NSLog(@"%s error deleting file at %@: %@", __PRETTY_FUNCTION__, URL, error);
        }
    }
}

#pragma mark - UIApplicationDelegate

#pragma mark Launching and backgrounding

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _instance = self;
    
    [GRMustache preventNSUndefinedKeyExceptionAttack];
    
    [[AwfulSettings sharedSettings] registerDefaults];
    [[AwfulSettings sharedSettings] migrateOldSettings];
    
    NSURL *storeURL = [[[NSFileManager defaultManager] applicationSupportDirectory] URLByAppendingPathComponent:@"CachedForumData"
                                                                                                    isDirectory:YES];
    NSURL *modelURL = [[NSBundle bundleForClass:[DataStore class]] URLForResource:@"Awful" withExtension:@"momd"];
    _dataStore = [[DataStore alloc] initWithStoreDirectoryURL:storeURL modelURL:modelURL];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        RemoveOldDataStores();
    });
    
    [AwfulForumsClient sharedClient].managedObjectContext = self.managedObjectContext;
    [self updateClientBaseURL];
    
    __weak __typeof__(self) weakSelf = self;
    [AwfulForumsClient sharedClient].didRemotelyLogOutBlock = ^{
        [weakSelf logOut];
    };
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:5 * 1024 * 1024
                                                                diskCapacity:50 * 1024 * 1024
                                                                    diskPath:nil]];
    [NSURLProtocol registerClass:[AwfulImageURLProtocol class]];
    [NSURLProtocol registerClass:[AwfulMinusFixURLProtocol class]];
    [NSURLProtocol registerClass:[ResourceURLProtocol class]];
    [NSURLProtocol registerClass:[AwfulWaffleimagesURLProtocol class]];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.tintColor = [Theme currentTheme][@"tintColor"];
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
    
    [[NewMessageChecker sharedChecker] refreshIfNecessary];
    
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

- (void)applicationWillResignActive:(UIApplication *)application
{
    SmilieKeyboardSetIsAwfulAppActive(NO);
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    SmilieKeyboardSetIsAwfulAppActive(YES);
    
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
    
    NSString *message = [NSString stringWithFormat:@"Would you like to open this URL in Awful?\n\n%@", URL.awful_absoluteUnicodeString];
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

- (void)application:(UIApplication *)application didDecodeRestorableStateWithCoder:(NSCoder *)coder
{
    // We may have created some new objects during state restoration, so let's do a save now that that's done.
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
    }
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
     * Interface for Awful 3, the version that runs on iOS 8. The primary view controller is a UISplitViewController on both iPhone and iPad.
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

#pragma mark Handoff

- (void)application:(UIApplication *)application didUpdateUserActivity:(NSUserActivity *)userActivity
{
    // Bit of future-proofing.
    [userActivity addUserInfoEntriesFromDictionary:@{Handoff.InfoVersionKey: @(HandoffVersion)}];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler
{
    NSURL *awfulURL = userActivity.awfulURL;
    if (awfulURL) {
        [self.URLRouter routeURL:awfulURL];
        return YES;
    }
    return NO;
}

static const NSInteger HandoffVersion = 1;

@end
