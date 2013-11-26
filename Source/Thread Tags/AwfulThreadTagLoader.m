//  AwfulThreadTagLoader.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagLoader.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulUIKitAndFoundationCategories.h"

@interface AwfulThreadTagLoader ()

@property (nonatomic) BOOL downloadingNewTags;

@end

@implementation AwfulThreadTagLoader
{
    AFHTTPSessionManager *_HTTPManager;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    NSString *URLString = [NSBundle mainBundle].infoDictionary[kNewThreadTagURLKey];
    _HTTPManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:URLString]];
    return self;
}

static NSString * const kNewThreadTagURLKey = @"AwfulNewThreadTagURL";

+ (AwfulThreadTagLoader *)loader
{
    static AwfulThreadTagLoader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (UIImage *)imageNamed:(NSString *)imageName
{
    NSParameterAssert(imageName.length > 0);
    NSString *imagePath = [@"Thread Tags" stringByAppendingPathComponent:imageName];
    UIImage *shipped = [UIImage imageNamed:imagePath];
    if (shipped) return EnsureDoubleScaledImage(shipped);
    
    NSURL *url = [[self cacheFolder] URLByAppendingPathComponent:imageName];
    if (url.pathExtension.length == 0) {
        url = [url URLByAppendingPathExtension:@"png"];
    }
    UIImage *cached = [UIImage imageWithContentsOfFile:url.path];
    if (cached) return EnsureDoubleScaledImage(cached);
    
    [self downloadNewThreadTags];
    return nil;
}

static UIImage *EnsureDoubleScaledImage(UIImage *image)
{
    if (image.scale == 2) return image;
    return [UIImage imageWithCGImage:image.CGImage scale:2 orientation:image.imageOrientation];
}

#pragma mark - Downloading tags

- (void)downloadNewThreadTags
{
    if (self.downloadingNewTags) return;
    NSDate *checked = [self lastCheck];
    // At most one check every six hours.
    if (checked && [checked timeIntervalSinceNow] > -60 * 60 * 6) return;
    self.downloadingNewTags = YES;
    
    [self ensureCacheFolder];
    [_HTTPManager GET:@"tags.txt" parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSString *tagsFile = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        [self saveTagsFile:tagsFile];
        NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
        NSArray *lines = [tagsFile componentsSeparatedByCharactersInSet:newlines];
        NSRange rest = NSMakeRange(1, [lines count] - 1);
        [self downloadNewThreadTagsInList:[lines subarrayWithRange:rest] fromRelativePath:lines[0]];
    } failure:nil];
}

- (void)downloadNewThreadTagsInList:(NSArray *)threadTags fromRelativePath:(NSString *)relativePath
{
    NSMutableArray *tagsToDownload = [threadTags mutableCopy];
    [tagsToDownload removeObjectsInArray:[self availableThreadTagNames]];
    __block NSUInteger remaining = tagsToDownload.count;
    for (NSString *threadTagName in tagsToDownload) {
        NSURL *URL = [NSURL URLWithString:[relativePath stringByAppendingPathComponent:threadTagName]
                            relativeToURL:_HTTPManager.baseURL];
        NSURLRequest *request = [_HTTPManager.requestSerializer requestWithMethod:@"GET"
                                                                        URLString:URL.absoluteString
                                                                       parameters:nil];
        NSURLSessionTask *task = [_HTTPManager downloadTaskWithRequest:request
                                                              progress:nil
                                                           destination:^(NSURL *targetPath, NSURLResponse *response)
        {
            return [[self cacheFolder] URLByAppendingPathComponent:threadTagName];
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            remaining--;
            if (remaining == 0) {
                self.downloadingNewTags = NO;
            }
            if (error) return;
            NSDictionary *userInfo = @{ AwfulThreadTagLoaderNewImageNameKey: [threadTagName stringByDeletingPathExtension] };
            [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThreadTagLoaderNewImageAvailableNotification
                                                                object:self
                                                              userInfo:userInfo];
        }];
        [task resume];
    }
}

#pragma mark - Caching tags

- (NSURL *)cacheFolder
{
    NSURL *caches = [[NSFileManager defaultManager] cachesDirectory];
    return [caches URLByAppendingPathComponent:@"Thread Tags"];
}

- (void)ensureCacheFolder
{
    NSError *error;
    BOOL ok = [[NSFileManager defaultManager] createDirectoryAtURL:[self cacheFolder]
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error];
    if (!ok) {
        NSLog(@"error creating thread tag cache folder %@: %@", [self cacheFolder], error);
    }
}

- (NSDate *)lastCheck
{
    NSURL *url = [self cachedTagsFile];
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path]
                                                                                error:&error];
    if (!attributes && [error code] != NSFileReadNoSuchFileError) {
        NSLog(@"error checking modification date of cached thread tags list %@: %@", url, error);
        return nil;
    }
    return [attributes fileModificationDate];
}

- (NSURL *)cachedTagsFile
{
    return [[self cacheFolder] URLByAppendingPathComponent:@"tags.txt"];
}

- (void)saveTagsFile:(NSString *)tagsFile
{
    [self ensureCacheFolder];
    NSError *error;
    BOOL ok = [tagsFile writeToURL:[self cachedTagsFile]
                        atomically:NO
                          encoding:NSUTF8StringEncoding
                             error:&error];
    if (!ok) {
        NSLog(@"error saving tags file to %@: %@", [self cachedTagsFile], error);
    }
}

- (NSArray *)availableThreadTagNames
{
    NSString *pathToResources = [[NSBundle mainBundle] resourcePath];
    NSError *error;
    NSArray *resources = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathToResources
                                                                             error:&error];
    if (!resources) {
        NSLog(@"error listing resources at %@: %@", pathToResources, error);
        return @[];
    }
    resources = [resources valueForKey:@"lastPathComponent"];
    
    NSArray *cached = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self cacheFolder]
                                                    includingPropertiesForKeys:nil
                                                                       options:0
                                                                         error:&error];
    if (!cached) {
        NSLog(@"error listing cached thread tags at %@: %@", [self cacheFolder], error);
        return resources;
    }
    cached = [cached valueForKey:@"lastPathComponent"];
    
    return [resources arrayByAddingObjectsFromArray:cached];
}

- (UIImage *)emptyThreadTagImage
{
    return [UIImage imageNamed:@"empty-thread-tag"];
}

- (UIImage *)emptyPrivateMessageImage
{
    return [UIImage imageNamed:@"empty-pm-tag"];
}

@end

NSString * const AwfulThreadTagLoaderNewImageAvailableNotification = @"com.awfulapp.Awful.ThreadTagLoaderNewImageAvailable";

NSString * const AwfulThreadTagLoaderNewImageNameKey = @"AwfulThreadTagLoaderNewImageName";
