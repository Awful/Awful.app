//  AwfulImageURLProtocol.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulImageURLProtocol.h"
@import MobileCoreServices;
@import Photos;

@implementation AwfulImageURLProtocol

NSString * const AwfulImageURLScheme = @"awful-image";

static NSMutableDictionary *g_imageDatas;

+ (NSURL *)serveImage:(UIImage *)image atPath:(NSString *)path
{
    NSParameterAssert(image);
    NSParameterAssert(path.length > 0);
    
    NSData *imageData = UIImagePNGRepresentation(image);
    return [self serveImageData:imageData atPath:path];
}

+ (NSURL *)serveAsset:(NSURL *)assetURL atPath:(NSString *)path
{
    NSParameterAssert(assetURL);
    NSParameterAssert(path.length > 0);
    
    PHAsset *asset = [PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil].firstObject;
    if (!asset) {
        NSLog(@"%s could not find asset", __PRETTY_FUNCTION__);
        return nil;
    }
    
    __block NSURL *servedURL;
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.synchronous = YES;
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        if (imageData) {
            servedURL = [self serveImageData:imageData atPath:path];
        } else {
            NSLog(@"%s could not get image data", __PRETTY_FUNCTION__);
        }
    }];
    
    return servedURL;
}

+ (NSURL *)serveImageData:(NSData *)imageData atPath:(NSString *)path
{
    if (!g_imageDatas) g_imageDatas = [NSMutableDictionary new];
    
    path = CanonicalizePath(path);
    g_imageDatas[path] = imageData;
    
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = AwfulImageURLScheme;
    
    // See NOTE in CanonicalPathFromURL.
    components.path = path;
    
    return components.URL;
}

+ (void)stopServingImageAtURL:(NSURL *)URL
{
    NSString *path = CanonicalPathFromURL(URL);
    [g_imageDatas removeObjectForKey:path];
}

static NSString * CanonicalizePath(NSString *path)
{
    return path.lowercaseString;
}

static NSString * CanonicalPathFromURL(NSURL *URL)
{
    // NOTE: URLs tend to look something like "awful-image:ABC123-ABC-ABC-ABC123/0". NSURLComponents will parse everything after the colon as the "path", but NSURL refuses. For awful-image URLs, -[NSURLComponents path] is thought to be equivalent to -[NSURL resourceSpecifier].
    return CanonicalizePath(URL.resourceSpecifier);
}

#pragma mark - NSURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if ([request.URL.scheme caseInsensitiveCompare:AwfulImageURLScheme] != NSOrderedSame) return NO;
    
    NSString *path = CanonicalPathFromURL(request.URL);
    return path && g_imageDatas[path];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = AwfulImageURLScheme;
    components.path = CanonicalPathFromURL(request.URL);
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    mutableRequest.URL = components.URL;
    return mutableRequest;
}

- (void)startLoading
{
    NSString *path = CanonicalPathFromURL(self.request.URL);
    NSData *data = g_imageDatas[path];
    NSDictionary *headers = @{ @"Content-Type": @"image/png",
                               @"Content-Length": @(data.length).stringValue };
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
    // nop – we do all our work in -startLoading.
}

@end
