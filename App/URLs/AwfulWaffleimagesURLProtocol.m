//  AwfulWaffleimagesURLProtocol.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulWaffleimagesURLProtocol.h"

@interface AwfulWaffleimagesURLProtocol ()

@property (nonatomic) NSURLSessionDataTask *downloadTask;

@end

@implementation AwfulWaffleimagesURLProtocol

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
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (response) {
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        }
        
        if (error) {
            [self.client URLProtocol:self didFailWithError:error];
        } else {
            if (data) {
                [self.client URLProtocol:self didLoadData:data];
            }
            
            [self.client URLProtocolDidFinishLoading:self];
        }
        
        self.downloadTask = nil;
    }];
    [task resume];
    self.downloadTask = task;
}

- (void)stopLoading
{
    [self.downloadTask cancel];
    self.downloadTask = nil;
}

@end
