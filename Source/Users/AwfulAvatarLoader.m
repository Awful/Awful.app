//  AwfulAvatarLoader.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAvatarLoader.h"
#import "AwfulFrameworkCategories.h"
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
        NSURL *cacheFolder = [[[NSFileManager defaultManager] cachesDirectory] URLByAppendingPathComponent:@"Avatars" isDirectory:YES];
        instance = [[self alloc] initWithCacheFolder:cacheFolder];
    });
    return instance;
}

- (id)initWithCacheFolder:(NSURL *)cacheFolder
{
    if ((self = [super init])) {
        _cacheFolder = cacheFolder;
        _sessionManager = [AFURLSessionManager new];
    }
    return self;
}

- (void)createCacheFolderIfNecessary
{
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating avatar cache folder %@: %@", __PRETTY_FUNCTION__, self.cacheFolder, error);
    }
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
        if (completionBlock) completionBlock(nil, YES, nil);
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
                                     destination:^(NSURL *targetPath, NSURLResponse *response)
     {
         [self createCacheFolderIfNecessary];
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
    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtURL:self.cacheFolder error:&error]) {
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError) return;
        NSLog(@"%s error deleting avatar cache at %@: %@", __PRETTY_FUNCTION__, self.cacheFolder, error);
    }
}

@end
