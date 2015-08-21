//  AwfulAvatarLoader.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAvatarLoader.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulFrameworkCategories.h"
#import "CacheHeaderCalculations.h"
@import ImageIO;
#import "Awful-Swift.h"

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

- (instancetype)initWithCacheFolder:(NSURL *)cacheFolder
{
    if ((self = [super init])) {
        _cacheFolder = cacheFolder;
        _sessionManager = [AFURLSessionManager new];
    }
    return self;
}

- (instancetype)init
{
    NSAssert(nil, @"Use -initWithCacheFolder: instead");
    return [self initWithCacheFolder:nil];
}

- (void)createCacheFolderIfNecessary
{
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating avatar cache folder %@: %@", __PRETTY_FUNCTION__, self.cacheFolder, error);
    }
}

- (id)cachedAvatarImageForUser:(User *)user
{
    NSURL *imageURL = [self imageURLForUser:user];
    return ImageAtURL(imageURL);
}

static id ImageAtURL(NSURL *imageURL)
{
    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
    if (!imageData) return nil;
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, nil);
    if (UTTypeConformsTo(CGImageSourceGetType(imageSource), kUTTypeGIF)) {
        return [[FLAnimatedImage alloc] initWithAnimatedGIFData:imageData];
    } else {
        return [UIImage imageWithData:imageData];
    }
}

- (void)fetchAvatarImageForUser:(User *)user
                completionBlock:(void (^)(BOOL modified, id image, NSError *error))completionBlock
{
    NSURL *avatarURL = user.avatarURL;
    if (avatarURL.path.length == 0) {
        if (completionBlock) {
            completionBlock(YES, nil, nil);
        }
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:avatarURL];
    
    NSURL *cachedResponseURL = [self cachedResponseURLForUser:user];
    NSHTTPURLResponse *cachedResponse = [NSKeyedUnarchiver unarchiveObjectWithFile:cachedResponseURL.path];
    if ([cachedResponse.URL isEqual:avatarURL]) {
        SetCacheHeadersForRequest(request, cachedResponse);
    }
    
    NSURLSessionDownloadTask *downloadTask =
    [self.sessionManager downloadTaskWithRequest:request
                                        progress:nil
                                     destination:^NSURL *(NSURL *targetPath, NSURLResponse *response)
     {
         // The download task won't overwrite an existing file, so we need to delete it here if we got an OK response. This block still gets called on e.g. a 304 response, even though the resulting file has no data, so we need to consider that.
         NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
         if (HTTPResponse.statusCode >= 200 && HTTPResponse.statusCode < 300) {
             [self createCacheFolderIfNecessary];
             NSURL *destinationURL = [self imageURLForUser:user];
             NSError *error;
             if (![[NSFileManager defaultManager] removeItemAtURL:destinationURL error:&error]) {
                 
                 // It's OK if deletion fails because the file wasn't there in the first place.
                 if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code != NSFileNoSuchFileError) {
                     NSLog(@"%s error saving avatar to %@: %@", __PRETTY_FUNCTION__, destinationURL, error);
                 }
             }
             return destinationURL;
         } else {
             return nil;
         }
     } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
         [NSKeyedArchiver archiveRootObject:response toFile:cachedResponseURL.path];
         if (completionBlock) {
             id image;
             if (error) {
                 NSHTTPURLResponse *response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
                 if (response.statusCode == 304) {
                     completionBlock(NO, nil, nil);
                     return;
                 }
             } else {
                 image = ImageAtURL(filePath);
             }
             completionBlock(YES, image, error);
         }
     }];
    [downloadTask resume];
}

- (NSURL *)imageURLForUser:(User *)user
{
    NSParameterAssert(user.userID.length > 0);
    
    return [[self.cacheFolder URLByAppendingPathComponent:user.userID] URLByAppendingPathExtension:@"image"];
}

- (NSURL *)cachedResponseURLForUser:(User *)user
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
