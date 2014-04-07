//  AwfulResourceURLProtocol.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulResourceURLProtocol.h"

@implementation AwfulResourceURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSString *scheme = request.URL.scheme;
    return scheme && [scheme caseInsensitiveCompare:@"awful-resource"] == NSOrderedSame;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSURL *originalURL = request.URL;
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = originalURL.scheme;
    components.host = originalURL.host;
    NSMutableURLRequest *newRequest = [request mutableCopy];
    newRequest.URL = components.URL;
    return newRequest;
}

- (void)startLoading
{
    NSURL *URL = self.request.URL;
    NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:URL.host withExtension:nil];
    
    NSError *error;
    NSData *resourceData = [NSData dataWithContentsOfURL:resourceURL options:0 error:&error];
    if (!resourceData) {
        [self.client URLProtocol:self didFailWithError:error];
        return;
    }
    
    NSString *MIMEType = @"application/octet-stream";
    NSString *extension = resourceURL.pathExtension;
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, nil);
    if (UTI) {
        NSString *associatedMIMEType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
        if (associatedMIMEType) {
            MIMEType = associatedMIMEType;
        }
    }
    
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:URL MIMEType:MIMEType expectedContentLength:resourceData.length textEncodingName:nil];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    [self.client URLProtocol:self didLoadData:resourceData];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
    // noop
}

@end
