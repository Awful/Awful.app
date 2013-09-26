//  AwfulMinusFixURLProtocol.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulMinusFixURLProtocol.h"

@interface AwfulMinusFixURLProtocol () <NSURLConnectionDataDelegate>

@end

@implementation AwfulMinusFixURLProtocol
{
    NSURLConnection *_connection;
}

// Minus checks the HTTP Referer for inlined images and redirects to an HTML page if it doesn't like what it finds. Threads on the Forums are allowed through, but in Awful the requests don't have the right referrer. This simple protocol fixes that oversight.

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (![request.URL.scheme isEqualToString:@"http"]) {
        return NO;
    }
    if (![request.HTTPMethod isEqualToString:@"GET"]) {
        return NO;
    }
    if (![request.URL.host hasSuffix:@"i.minus.com"]) {
        return NO;
    }
    if ([NSURLProtocol propertyForKey:DidSetRefererForMinusKey inRequest:request]) {
        return NO;
    }
    return YES;
}

static NSString * const DidSetRefererForMinusKey = @"com.awfulapp.Awful.DidSetRefererForMinus";

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSMutableURLRequest *request = [self.request mutableCopy];
    [request setValue:@"http://forums.somethingawful.com/" forHTTPHeaderField:@"Referer"];
    [NSURLProtocol setProperty:@YES forKey:DidSetRefererForMinusKey inRequest:request];
    _connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)stopLoading
{
    [_connection cancel];
    _connection = nil;
}

#pragma mark NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
    _connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.client URLProtocolDidFinishLoading:self];
    _connection = nil;
}

@end
