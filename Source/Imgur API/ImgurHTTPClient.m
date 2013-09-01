//  ImgurHTTPClient.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ImgurHTTPClient.h"
#import "UIImage+Resize.h"

// Rotates each image's data to match its UIImage imageOrientation, then downscales any images
// larger than Imgur's file size limit, and saves the end result as a PNG image.
@interface ImageResizeOperation : NSOperation

- (id)initWithImages:(NSArray *)images;

@property (copy, nonatomic) NSArray *images;

@property (copy, nonatomic) NSArray *resizedImageDatas;

@end


// Collects the URLs for the uploaded images, and cancels all related operations when cancelled.
@interface URLCollectionOperation : NSOperation <ImgurHTTPClientCancelToken>

@property (nonatomic) ImageResizeOperation *resizeOperation;

@property (copy, nonatomic) NSArray *uploadOperations;

@property (copy, nonatomic) void (^callback)(NSError *error, NSArray *urls);

- (void)cancelWithError:(NSError *)error;

@end


@implementation ImgurHTTPClient

+ (ImgurHTTPClient *)client
{
    static ImgurHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.imgur.com/"]];
    });
    return instance;
}

- (id)initWithBaseURL:(NSURL *)url
{
    if (!(self = [super initWithBaseURL:url])) return nil;
    [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    [self setDefaultHeader:@"Authorization" value:@"Client-ID 4db466addcb5cfc"];
    return self;
}

- (id <ImgurHTTPClientCancelToken>)uploadImages:(NSArray *)images
                                        andThen:(void(^)(NSError *error, NSArray *urls))callback
{
    URLCollectionOperation *urlOp = [URLCollectionOperation new];
    urlOp.queuePriority = NSOperationQueuePriorityVeryHigh;
    urlOp.callback = callback;
    urlOp.resizeOperation = [[ImageResizeOperation alloc] initWithImages:images];
    __weak URLCollectionOperation *weakURLOp = urlOp;
    urlOp.resizeOperation.completionBlock = ^{
        [self uploadImageDatasForURLCollectionOperation:weakURLOp];
    };
    [self.operationQueue addOperation:urlOp.resizeOperation];
    [self.operationQueue addOperation:urlOp];
    return urlOp;
}

- (void)uploadImageDatasForURLCollectionOperation:(URLCollectionOperation *)urlOp
{
    NSMutableArray *operations = [NSMutableArray new];
    for (NSData *imageData in urlOp.resizeOperation.resizedImageDatas) {
        NSURLRequest *request = [self multipartFormRequestWithMethod:@"POST"
                                                                path:@"/3/image.json"
                                                          parameters:nil
                                           constructingBodyWithBlock:^(id<AFMultipartFormData> form)
        {
            [form appendPartWithFileData:imageData
                                    name:@"image"
                                fileName:@"image.png"
                                mimeType:@"image/png"];
        }];
        [operations addObject:[self HTTPRequestOperationWithRequest:request
                                                            success:nil failure:nil]];
    }
    urlOp.uploadOperations = operations;
    [self enqueueBatchOfHTTPRequestOperations:operations progressBlock:nil completionBlock:nil];
}

@end


@implementation ImageResizeOperation

- (id)initWithImages:(NSArray *)images
{
    if (!(self = [super init])) return nil;
    _images = [images copy];
    return self;
}

- (void)main
{
    NSMutableArray *imageDatas = [NSMutableArray new];
    for (__strong UIImage *image in _images) {
        if ([self isCancelled]) return;
        // -resizedImage:interpolationQuality: will rotate the image data for us, so we call it
        // once unconditionally.
        image = [image resizedImage:image.size interpolationQuality:kCGInterpolationHigh];
        const NSUInteger TenMB = 10485760;
        NSData *data = UIImagePNGRepresentation(image);
        while ([data length] > TenMB && ![self isCancelled]) {
            CGSize newSize = CGSizeMake(image.size.width / 2, image.size.height / 2);
            image = [image resizedImage:newSize interpolationQuality:kCGInterpolationHigh];
            data = UIImagePNGRepresentation(image);
        }
        [imageDatas addObject:data];
    }
    self.resizedImageDatas = imageDatas;
}

@end


@implementation URLCollectionOperation

- (void)setResizeOperation:(ImageResizeOperation *)resizeOperation
{
    if (_resizeOperation == resizeOperation) return;
    [self willChangeValueForKey:@"resizeOperation"];
    if (_resizeOperation) [self removeDependency:_resizeOperation];
    _resizeOperation = resizeOperation;
    if (resizeOperation) [self addDependency:resizeOperation];
    [self didChangeValueForKey:@"resizeOperation"];
}

- (void)setUploadOperations:(NSArray *)uploadOperations
{
    if (_uploadOperations == uploadOperations) return;
    [self willChangeValueForKey:@"uploadOperations"];
    for (NSOperation *operation in _uploadOperations) {
        [self removeDependency:operation];
    }
    _uploadOperations = [uploadOperations copy];
    for (NSOperation *operation in uploadOperations) {
        [self addDependency:operation];
    }
    [self didChangeValueForKey:@"uploadOperations"];
}

- (void)cancelWithError:(NSError *)error
{
    if ([self isCancelled]) return;
    [self cancel];
    if (self.callback) {
        dispatch_async(dispatch_get_main_queue(), ^{ self.callback(error, nil); });
    }
}

#pragma mark - NSOperation

- (BOOL)isReady
{
    if (!self.resizeOperation || [self.uploadOperations count] == 0) return NO;
    return [super isReady];
}

- (void)main
{
    NSMutableArray *listOfURLs = [NSMutableArray new];
    for (AFJSONRequestOperation *operation in self.uploadOperations) {
        NSDictionary *response = operation.responseJSON;
        if (!operation.hasAcceptableStatusCode) {
            NSInteger errorCode = ImgurAPIErrorUnknown;
            if (operation.response.statusCode == 400) {
                errorCode = ImgurAPIErrorInvalidImage;
            } else if (operation.response.statusCode == 403) {
                errorCode = ImgurAPIErrorRateLimitExceeded;
            } else if (operation.response.statusCode == 404) {
                errorCode = ImgurAPIErrorActionNotSupported;
            } else if (operation.response.statusCode == 500) {
                errorCode = ImgurAPIErrorUnexpectedRemoteError;
            }
            NSString *message = response[@"data"][@"error"][@"message"];
            if (!message) message = @"An unknown error occurred";
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : message,
                NSUnderlyingErrorKey : operation.error
            };
            NSError *error = [NSError errorWithDomain:ImgurAPIErrorDomain
                                                 code:errorCode
                                             userInfo:userInfo];
            [self cancelWithError:error];
            return;
        }
        NSString *url = response[@"data"][@"link"];
        if (!url) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Missing image URL" };
            NSError *error = [NSError errorWithDomain:ImgurAPIErrorDomain
                                                 code:ImgurAPIErrorMissingImageURL
                                             userInfo:userInfo];
            [self cancelWithError:error];
            return;
        }
        [listOfURLs addObject:[NSURL URLWithString:url]];
    }
    if (self.callback) {
        dispatch_async(dispatch_get_main_queue(), ^{ self.callback(nil, listOfURLs); });
    }
}

- (void)cancel
{
    [super cancel];
    [self.resizeOperation cancel];
    [self.uploadOperations makeObjectsPerformSelector:@selector(cancel)];
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingIsReady
{
    return [NSSet setWithObjects:@"resizeOperation", @"uploadOperations", nil];
}

@end


NSString * const ImgurAPIErrorDomain = @"ImgurAPIErrorDomain";
