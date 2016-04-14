//  AwfulThreadTagLoader.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagLoader.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulFrameworkCategories.h"

@interface AwfulThreadTagLoader ()

@property (readonly, strong, nonatomic) NSURL *shippedThreadTagFolder;
@property (readonly, copy, nonatomic) NSArray *shippedThreadTagImageNames;
@property (readonly, copy, nonatomic) NSArray *cachedThreadTagImageNames;

@property (readonly, strong, nonatomic) AFHTTPSessionManager *HTTPManager;
@property (readonly, strong, nonatomic) NSDate *lastUpdate;
@property (readonly, strong, nonatomic) NSURL *cachedTagsFileURL;
@property (assign, nonatomic) BOOL downloadingNewTags;

@end

@implementation AwfulThreadTagLoader

@synthesize shippedThreadTagImageNames = _shippedThreadTagImageNames;
@synthesize HTTPManager = _HTTPManager;

- (instancetype)initWithTagListURL:(NSURL *)tagListURL cacheFolder:(NSURL *)cacheFolder
{
    if ((self = [super init])) {
        _tagListURL = tagListURL;
        _cacheFolder = cacheFolder;
        _HTTPManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[tagListURL URLByDeletingLastPathComponent]];
        
        AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
        responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/plain"];
        _HTTPManager.responseSerializer = responseSerializer;
    }
    return self;
}

- (UIImage *)imageNamed:(NSString *)imageName
{
    NSParameterAssert(imageName.length > 0);
    
    imageName = [imageName stringByDeletingPathExtension];
    UIImage *image = [self shippedImageNamed:imageName] ?: [self cachedImageNamed:imageName];
    if (!image) [self updateIfNecessary];
    return image;
}

#pragma mark - Resource images

static NSString * const ResourceSubfolder = @"Thread Tags";

- (NSURL *)shippedThreadTagFolder
{
    return [[NSBundle bundleForClass:self.class].resourceURL URLByAppendingPathComponent:ResourceSubfolder];
}

- (NSArray *)shippedThreadTagImageNames
{
    if (_shippedThreadTagImageNames) return _shippedThreadTagImageNames;
    
    NSArray *placeholderImageNames = @[ AwfulThreadTagLoaderEmptyThreadTagImageName,
                                        AwfulThreadTagLoaderEmptyPrivateMessageImageName,
                                        AwfulThreadTagLoaderUnsetThreadTagImageName,
                                        AwfulThreadTagLoaderNoFilterImageName ];
    
    NSError *error;
    NSArray *URLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.shippedThreadTagFolder
                                                  includingPropertiesForKeys:@[ NSURLPathKey ]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                       error:&error];
    if (!URLs) {
        NSLog(@"%s error listing thread tag resources: %@", __PRETTY_FUNCTION__, error);
        return nil;
    }
    
    _shippedThreadTagImageNames = [placeholderImageNames arrayByAddingObjectsFromArray:[URLs valueForKey:@"lastPathComponent"]];
    return _shippedThreadTagImageNames;
}

- (UIImage *)shippedImageNamed:(NSString *)imageName
{
    NSString *path = [ResourceSubfolder stringByAppendingPathComponent:imageName];
    UIImage *image = [UIImage imageNamed:path] ?: [UIImage imageNamed:imageName];
    return EnsureDoubleScaledImage(image);
}

static UIImage * EnsureDoubleScaledImage(UIImage *image)
{
    if (!image) return nil;
    
    if (image.scale >= 2) {
        return image;
    } else {
        return [UIImage imageWithCGImage:image.CGImage scale:2 orientation:image.imageOrientation];
    }
}

#pragma mark - Downloading images

- (NSDate *)lastUpdate
{
    NSURL *URL = self.cachedTagsFileURL;
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:URL.path error:&error];
    if (!attributes && error.code != NSFileReadNoSuchFileError) {
        NSLog(@"%s error checking modification date of cached thread tags list %@: %@", __PRETTY_FUNCTION__, URL, error);
    }
    if (attributes) {
        return [attributes fileModificationDate];
    } else {
        return [NSDate distantPast];
    }
}

- (void)updateIfNecessary
{
    if (self.downloadingNewTags) return;
    
    // At most one check every hour.
    if (self.lastUpdate.timeIntervalSinceNow > -60 * 60) return;
    
    self.downloadingNewTags = YES;
    [_HTTPManager GET:@"tags.txt" parameters:nil success:^(NSURLSessionDataTask *task, NSData *textData) {
        NSString *tagsFile = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
        [self saveTagsFile:tagsFile];
        NSArray *lines = [tagsFile componentsSeparatedByString:@"\n"];
        NSString *relativePath = lines[0];
        NSArray *threadTags = [lines subarrayWithRange:NSMakeRange(1, lines.count - 1)];
        [self downloadNewThreadTags:threadTags fromRelativePath:relativePath completionBlock:^{
            self.downloadingNewTags = NO;
        }];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"%s error downloading new thread tag list: %@", __PRETTY_FUNCTION__, error);
        self.downloadingNewTags = NO;
    }];
}

- (void)downloadNewThreadTags:(NSArray *)threadTags fromRelativePath:(NSString *)relativePath completionBlock:(void (^)(void))completionBlock
{
    // Using an ordered set because NSSet doesn't have -removeObjectsInArray:.
    NSMutableOrderedSet *tagsToDownload = [NSMutableOrderedSet orderedSetWithArray:threadTags];
    [tagsToDownload removeObjectsInArray:self.shippedThreadTagImageNames];
    [tagsToDownload removeObjectsInArray:self.cachedThreadTagImageNames];
    
    dispatch_group_t group = dispatch_group_create();
    for (NSString *threadTagName in tagsToDownload) {
        dispatch_group_enter(group);
        NSURL *URL = [NSURL URLWithString:[relativePath stringByAppendingPathComponent:threadTagName] relativeToURL:_HTTPManager.baseURL];
        NSURLRequest *request = [_HTTPManager.requestSerializer requestWithMethod:@"GET" URLString:URL.absoluteString parameters:nil error:nil];
        NSURLSessionTask *task = [_HTTPManager downloadTaskWithRequest:request progress:nil destination:^(NSURL *targetPath, NSURLResponse *response) {
            return [self.cacheFolder URLByAppendingPathComponent:threadTagName];
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            dispatch_group_leave(group);
            if (error) {
                NSLog(@"%s error downloading thread tag from %@: %@", __PRETTY_FUNCTION__, URL, error);
            } else {
                NSDictionary *userInfo = @{ AwfulThreadTagLoaderNewImageNameKey: [threadTagName stringByDeletingPathExtension] };
                [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThreadTagLoaderNewImageAvailableNotification object:self userInfo:userInfo];
            }
        }];
        [task resume];
    }
    if (completionBlock) dispatch_group_notify(group, dispatch_get_main_queue(), completionBlock);
}

#pragma mark - Caching images

- (NSURL *)cachedTagsFileURL
{
    return [self.cacheFolder URLByAppendingPathComponent:@"tags.txt"];
}

- (void)saveTagsFile:(NSString *)tagsFile
{
    [self ensureCacheFolder];
    NSError *error;
    if (![tagsFile writeToURL:self.cachedTagsFileURL atomically:NO encoding:NSUTF8StringEncoding error:&error]) {
        NSLog(@"%s error saving tags file to %@: %@", __PRETTY_FUNCTION__, self.cachedTagsFileURL, error);
    }
}

- (void)ensureCacheFolder
{
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating thread tag cache folder %@: %@", __PRETTY_FUNCTION__, self.cacheFolder, error);
    }
}

- (NSArray *)cachedThreadTagImageNames
{
    NSError *error;
    NSArray *URLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.cacheFolder
                                                  includingPropertiesForKeys:@[ NSURLPathKey ]
                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                       error:&error];
    if (!URLs) {
        NSLog(@"%s error listing cached thread tags: %@", __PRETTY_FUNCTION__, error);
        return nil;
    }
    return [URLs valueForKey:@"lastPathComponent"];
}

- (UIImage *)cachedImageNamed:(NSString *)imageName
{
    NSURL *URL = [[self.cacheFolder URLByAppendingPathComponent:imageName] URLByAppendingPathExtension:@"png"];
    UIImage *image = [UIImage imageWithContentsOfFile:URL.path];
    return EnsureDoubleScaledImage(image);
}

#pragma mark - Conveniences

+ (instancetype)sharedLoader {
    static AwfulThreadTagLoader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *tagListURL = [NSURL URLWithString:[NSBundle mainBundle].infoDictionary[@"AwfulNewThreadTagListURL"]];
        NSURL *caches = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSURL *cacheFolder = [caches URLByAppendingPathComponent:@"Thread Tags" isDirectory:YES];
        instance = [[self alloc] initWithTagListURL:tagListURL cacheFolder:cacheFolder];
    });
    return instance;
}

+ (UIImage *)imageNamed:(NSString *)imageName
{
    return [[self sharedLoader] imageNamed:imageName];
}

+ (UIImage *)emptyThreadTagImage
{
    return [UIImage imageNamed:AwfulThreadTagLoaderEmptyThreadTagImageName];
}

+ (UIImage *)emptyPrivateMessageImage
{
    return [UIImage imageNamed:AwfulThreadTagLoaderEmptyPrivateMessageImageName];
}

+ (UIImage *)unsetThreadTagImage
{
    return [UIImage imageNamed:AwfulThreadTagLoaderUnsetThreadTagImageName];
}

+ (UIImage *)noFilterTagImage
{
    return [UIImage imageNamed:AwfulThreadTagLoaderNoFilterImageName];
}

@end

NSString * const AwfulThreadTagLoaderNewImageAvailableNotification = @"com.awfulapp.Awful.ThreadTagLoaderNewImageAvailable";

NSString * const AwfulThreadTagLoaderNewImageNameKey = @"AwfulThreadTagLoaderNewImageName";

NSString * AwfulThreadTagLoaderEmptyThreadTagImageName = @"empty-thread-tag";
NSString * AwfulThreadTagLoaderEmptyPrivateMessageImageName = @"empty-pm-tag";
NSString * AwfulThreadTagLoaderUnsetThreadTagImageName = @"unset-tag";
NSString * AwfulThreadTagLoaderNoFilterImageName = @"no-filter-icon";
