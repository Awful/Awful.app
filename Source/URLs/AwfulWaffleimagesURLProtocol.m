//  AwfulWaffleimagesURLProtocol.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulWaffleimagesURLProtocol.h"

@interface AwfulWaffleimagesURLProtocol () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@end

@implementation AwfulWaffleimagesURLProtocol
{
    NSURLConnection *_connection;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSURL *URL = request.URL;
    if (URL.scheme.length == 0) return NO;
    return ([URL.scheme caseInsensitiveCompare:@"http"] == NSOrderedSame &&
            [URL.host.lowercaseString hasSuffix:@"waffleimages.com"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSURL *URL = request.URL;
    NSArray *pathComponents = URL.pathComponents;
    if (pathComponents.count < 2) return request; // TODO log this somewhere
    NSString *hash = pathComponents[1];
    if (hash.length < 2) return request; // TODO log this somewhere
    NSString *extension = URL.pathExtension;
    if (extension.length == 0) return request; // TODO log this somewhere
    if ([extension caseInsensitiveCompare:@"jpeg"] == NSOrderedSame) {
        extension = [extension stringByReplacingOccurrencesOfString:@"e" withString:@""];
    }
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithString:URL.absoluteString];
    URLComponents.host = @"randomwaffle.gbs.fm";
    URLComponents.path = [NSString stringWithFormat:@"/images/%@/%@.%@", [hash substringToIndex:2], hash, extension];
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    mutableRequest.URL = URLComponents.URL;
    return mutableRequest;
}

- (void)startLoading
{
    NSURLRequest *request = [[self class] canonicalRequestForRequest:self.request];
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)stopLoading
{
    [_connection cancel];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.client URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:self.request.cachePolicy];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return cachedResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.client URLProtocolDidFinishLoading:self];
}

@end
