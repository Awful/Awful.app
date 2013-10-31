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
    AFHTTPClient *_client;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    NSString *URLString = [NSBundle mainBundle].infoDictionary[kNewThreadTagURLKey];
    _client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:URLString]];
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

- (UIImage *)threadTagNamed:(NSString *)threadTagName
{
    if ([threadTagName length] == 0) return nil;
    UIImage *shipped = [UIImage imageNamed:[NSString stringWithFormat:@"Thread Tags/%@", threadTagName]];
    if (shipped) return EnsureDoubleScaledImage(shipped);
    
    NSURL *url = [[self cacheFolder] URLByAppendingPathComponent:threadTagName];
    if ([url.pathExtension length] == 0) {
        url = [url URLByAppendingPathExtension:@"png"];
    }
    UIImage *cached = [UIImage imageWithContentsOfFile:[url path]];
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
    NSURLRequest *request = [_client requestWithMethod:@"GET" path:@"tags.txt" parameters:nil];
    AFHTTPRequestOperation *op = [_client HTTPRequestOperationWithRequest:request success:^(id _, id responseObject) {
        NSString *tagsFile = [[NSString alloc] initWithData:responseObject
                                                   encoding:NSUTF8StringEncoding];
        [self saveTagsFile:tagsFile];
        NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
        NSArray *lines = [tagsFile componentsSeparatedByCharactersInSet:newlines];
        NSRange rest = NSMakeRange(1, [lines count] - 1);
        [self downloadNewThreadTagsInList:[lines subarrayWithRange:rest] fromRelativePath:lines[0]];
    } failure:nil];
    [_client enqueueHTTPRequestOperation:op];
}

- (void)downloadNewThreadTagsInList:(NSArray *)threadTags fromRelativePath:(NSString *)relativePath
{
    NSMutableArray *tagsToDownload = [threadTags mutableCopy];
    [tagsToDownload removeObjectsInArray:[self availableThreadTagNames]];
    NSMutableArray *batchOfOperations = [NSMutableArray new];
    for (NSString *threadTagName in tagsToDownload) {
        NSString *path = [relativePath stringByAppendingPathComponent:threadTagName];
        NSURLRequest *request = [_client requestWithMethod:@"GET" path:path parameters:nil];
        AFHTTPRequestOperation *op = [_client HTTPRequestOperationWithRequest:request success:nil failure:nil];
        NSURL *outURL = [[self cacheFolder] URLByAppendingPathComponent:threadTagName];
        op.outputStream = [NSOutputStream outputStreamWithURL:outURL append:NO];
        [batchOfOperations addObject:op];
    }
    
    [self ensureCacheFolder];
    [_client enqueueBatchOfHTTPRequestOperations:batchOfOperations
                                progressBlock:nil
                              completionBlock:^(NSArray *operations)
    {
        self.downloadingNewTags = NO;
        NSMutableArray *newlyAvailableTagNames = [NSMutableArray new];
        for (AFHTTPRequestOperation *op in operations) {
            if ([op hasAcceptableStatusCode]) {
                [newlyAvailableTagNames addObject:[[op.request URL] lastPathComponent]];
            }
        }
        if ([newlyAvailableTagNames count] == 0) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:AwfulNewThreadTagsAvailableNotification
                                                                object:newlyAvailableTagNames];
        });
    }];
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

@end

NSString * const AwfulNewThreadTagsAvailableNotification = @"com.awfulapp.Awful.NewThreadTagsAvailable";
