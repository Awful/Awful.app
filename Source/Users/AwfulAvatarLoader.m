//  AwfulAvatarLoader.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAvatarLoader.h"
#import <AFNetworking/AFNetworking.h>

@interface AwfulAvatarLoader ()

@property (strong, nonatomic) AFURLSessionManager *sessionManager;

@end

@implementation AwfulAvatarLoader

+ (instancetype)loader
{
    static AwfulAvatarLoader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *cachesFolder = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        NSURL *cacheFolder = [cachesFolder URLByAppendingPathComponent:@"Avatars" isDirectory:YES];
        instance = [[self alloc] initWithCacheFolder:cacheFolder];
    });
    return instance;
}

- (id)initWithCacheFolder:(NSURL *)cacheFolder
{
    self = [super init];
    if (!self) return nil;
    
    _cacheFolder = cacheFolder;
    _sessionManager = [AFURLSessionManager new];
    NSError *error;
    BOOL ok = [[NSFileManager defaultManager] createDirectoryAtURL:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error];
    if (!ok) {
        NSLog(@"%s error creating avatar cache folder %@: %@", __PRETTY_FUNCTION__, cacheFolder, error);
    }
    
    return self;
}

- (UIImage *)cachedAvatarImageForUser:(AwfulUser *)user
{
    NSURL *imageURL = [self imageURLForUser:user];
    return [UIImage imageWithContentsOfFile:imageURL.path];
}

- (void)avatarImageForUser:(AwfulUser *)user completion:(void (^)(UIImage *avatarImage, BOOL modified, NSError *error))completionBlock
{
    NSURL *avatarURL = user.avatarURL;
    if (avatarURL.path.length == 0) {
        if (completionBlock) {
            completionBlock(nil, YES, nil);
        }
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:avatarURL];
    
    NSURL *cachedResponseURL = [self cachedResponseURLForUser:user];
    NSHTTPURLResponse *cachedResponse = [NSKeyedUnarchiver unarchiveObjectWithFile:cachedResponseURL.path];
    if ([cachedResponse.URL isEqual:avatarURL]) {
        NSDictionary *headers = [cachedResponse allHeaderFields];
        NSString *etag = headers[@"Etag"];
        if (etag) {
            [request setValue:etag forHTTPHeaderField:@"If-None-Match"];
        }
        NSString *lastModified = headers[@"Last-Modified"];
        if (lastModified) {
            [request setValue:lastModified forHTTPHeaderField:@"If-Modified-Since"];
        }
    }
    
    NSURLSessionDownloadTask *downloadTask =
    [self.sessionManager downloadTaskWithRequest:request
                                        progress:nil
                                     destination:^NSURL *(NSURL *targetPath, NSURLResponse *response)
     {
         return [self imageURLForUser:user];
     } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
         [NSKeyedArchiver archiveRootObject:response toFile:cachedResponseURL.path];
         if (completionBlock) {
             UIImage *image;
             if (error) {
                 NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
                 if (response.statusCode == 304) {
                     completionBlock(nil, NO, nil);
                     return;
                 }
             } else {
                 image = [UIImage imageWithContentsOfFile:filePath.path];
             }
             completionBlock(image, YES, error);
         }
     }];
    [downloadTask resume];
}

- (NSURL *)imageURLForUser:(AwfulUser *)user
{
    NSParameterAssert(user.userID.length > 0);
    
    return [[self.cacheFolder URLByAppendingPathComponent:user.userID] URLByAppendingPathExtension:@"image"];
}

- (NSURL *)cachedResponseURLForUser:(AwfulUser *)user
{
    NSParameterAssert(user.userID.length > 0);
    
    return [[self.cacheFolder URLByAppendingPathComponent:user.userID] URLByAppendingPathExtension:@"cachedresponse"];
}

- (void)emptyCache
{
    BOOL (^errorHandler)(NSURL *, NSError *) = ^(NSURL *URL, NSError *error) {
        NSLog(@"%s error enumerating cached avatar item %@: %@", __PRETTY_FUNCTION__, URL, error);
        return YES;
    };
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsSubdirectoryDescendants & NSDirectoryEnumerationSkipsHiddenFiles;
    NSEnumerator *URLEnumerator = [fileManager enumeratorAtURL:self.cacheFolder includingPropertiesForKeys:nil options:options errorHandler:errorHandler];
    for (NSURL *URL in URLEnumerator) {
        NSError *error;
        BOOL ok = [fileManager removeItemAtURL:URL error:&error];
        if (!ok) {
            NSLog(@"%s error deleting cached avatar item %@: %@", __PRETTY_FUNCTION__, URL, error);
        }
    }
}

@end
