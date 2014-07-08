//  AwfulResourceURLProtocol.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulResourceURLProtocol.h"
#import "AwfulFrameworkCategories.h"

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
    
    // awful-resource:// URLs are pretty hackneyed. Resource names can include an @, like "image@2x.png". URL parsing would split that up into a user part "image" and a host part "2x.png". So we'll parse it ourselves, with the slashes being optional after the scheme.
    NSScanner *scanner = [NSScanner scannerWithString:URL.awful_absoluteUnicodeString];
    scanner.charactersToBeSkipped = nil;
    [scanner scanString:@"awful-resource:" intoString:nil];
    [scanner scanString:@"/" intoString:nil];
    [scanner scanString:@"/" intoString:nil];
    NSString *resourceName = [scanner.string substringFromIndex:scanner.scanLocation];
    
    NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:resourceName withExtension:nil];
    if (!resourceURL) {
        NSLog(@"%s could not find resource for URL %@", __PRETTY_FUNCTION__, URL);
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:@{ NSLocalizedDescriptionKey: @"Invalid URL" }];
        [self.client URLProtocol:self didFailWithError:error];
        return;
    }
    
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
