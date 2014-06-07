//  AwfulImageURLProtocol.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulImageURLProtocol.h"

@implementation AwfulImageURLProtocol

NSString * const AwfulImageURLScheme = @"awful-image";

static NSMutableDictionary *g_imageDatas;

+ (NSURL *)serveImage:(UIImage *)image atPath:(NSString *)path
{
    NSParameterAssert(image);
    NSParameterAssert(path.length > 0);
    
    if (!g_imageDatas) g_imageDatas = [NSMutableDictionary new];
    
    path = CanonicalizePath(path);
    g_imageDatas[path] = UIImagePNGRepresentation(image);
    
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
