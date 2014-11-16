//  AwfulPostsViewExternalStylesheetLoader.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsViewExternalStylesheetLoader.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulRefreshMinder.h"
#import "CacheHeaderCalculations.h"

@interface AwfulPostsViewExternalStylesheetLoader ()

@property (copy, nonatomic) NSString *stylesheet;

@property (readonly, strong, nonatomic) AFURLSessionManager *sessionManager;
@property (assign, nonatomic) BOOL checkingForUpdate;
@property (readonly, strong, nonatomic) NSURL *cachedResponseURL;
@property (readonly, strong, nonatomic) NSURL *cachedStylesheetURL;

@property (strong, nonatomic) NSTimer *updateTimer;

@end

@implementation AwfulPostsViewExternalStylesheetLoader

+ (instancetype)loader
{
    static AwfulPostsViewExternalStylesheetLoader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *stylesheetURL = [NSURL URLWithString:[NSBundle mainBundle].infoDictionary[AwfulPostsViewExternalStylesheetLoaderStylesheetURLKey]];
        NSURL *cacheFolder = [[[NSFileManager defaultManager] cachesDirectory] URLByAppendingPathComponent:@"ExternalStylesheet" isDirectory:YES];
        instance = [[self alloc] initWithStylesheetURL:stylesheetURL cacheFolder:cacheFolder];
    });
    return instance;
}

- (instancetype)initWithStylesheetURL:(NSURL *)stylesheetURL cacheFolder:(NSURL *)cacheFolder
{
    if ((self = [super init])) {
        _stylesheetURL = stylesheetURL;
        _cacheFolder = cacheFolder;
        _sessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [self startTimer];
    }
    return self;
}

- (NSString *)stylesheet
{
    if (!_stylesheet) [self reloadCachedStylesheet];
    return _stylesheet ?: @"";
}

- (NSURL *)cachedResponseURL
{
    return [self.cacheFolder URLByAppendingPathComponent:@"style.cachedresponse"];
}

- (NSURL *)cachedStylesheetURL
{
    return [self.cacheFolder URLByAppendingPathComponent:@"style.css"];
}

- (void)refreshIfNecessary
{
    if (![[AwfulRefreshMinder minder] shouldRefreshExternalStylesheet] || self.checkingForUpdate) return;
    
    self.checkingForUpdate = YES;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.stylesheetURL];
    NSHTTPURLResponse *cachedResponse = [NSKeyedUnarchiver unarchiveObjectWithFile:self.cachedResponseURL.path];
    if ([cachedResponse.URL isEqual:self.stylesheetURL]) {
        SetCacheHeadersForRequest(request, cachedResponse);
    }
    
    NSURLSessionDownloadTask *task =
    [self.sessionManager downloadTaskWithRequest:request
                                        progress:nil
                                     destination:^(NSURL *targetPath, NSURLResponse *response)
    {
        [self createCacheFolderIfNecessary];
        return self.cachedStylesheetURL;
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        self.checkingForUpdate = NO;
        if (error) {
            NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
            if (response.statusCode == 304) {
                [[AwfulRefreshMinder minder] didFinishRefreshingExternalStylesheet];
            } else {
                NSLog(@"%s error updating external stylesheet: %@", __PRETTY_FUNCTION__, error);
            }
        } else {
            [NSKeyedArchiver archiveRootObject:response toFile:self.cachedResponseURL.path];
            [self reloadCachedStylesheet];
            [[AwfulRefreshMinder minder] didFinishRefreshingExternalStylesheet];
            [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPostsViewExternalStylesheetLoaderDidUpdateNotification object:self.stylesheet];
        }
    }];
    [task resume];
}

- (void)createCacheFolderIfNecessary
{
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating external stylesheet cache folder %@: %@", __PRETTY_FUNCTION__, self.cacheFolder, error);
    }
}

- (void)reloadCachedStylesheet
{
    self.stylesheet = [NSString stringWithContentsOfURL:self.cachedStylesheetURL usedEncoding:nil error:nil];
}

- (void)emptyCache
{
    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtURL:self.cacheFolder error:&error]) {
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError) return;
        NSLog(@"%s error deleting external stylesheet cache at %@: %@", __PRETTY_FUNCTION__, self.cacheFolder, error);
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)note
{
    [self refreshIfNecessary];
    [self startTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)note
{
    [self stopTimer];
}

- (void)startTimer
{
    NSTimeInterval interval = [[[AwfulRefreshMinder minder] suggestedDateToRefreshExternalStylesheet] timeIntervalSinceNow];
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timerDidFire:) userInfo:nil repeats:NO];
}

- (void)stopTimer
{
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)timerDidFire:(NSTimer *)timer
{
    self.updateTimer = nil;
    [self refreshIfNecessary];
}

@end

NSString * const AwfulPostsViewExternalStylesheetLoaderStylesheetURLKey = @"AwfulPostsViewExternalStylesheetURL";

NSString * const AwfulPostsViewExternalStylesheetLoaderDidUpdateNotification = @"AwfulPostsViewExternalStylesheetDidUpdate";
