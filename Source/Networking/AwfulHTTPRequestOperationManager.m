//  AwfulHTTPRequestOperationManager.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTTPRequestOperationManager.h"
#import "AwfulHTMLRequestSerializer.h"
#import "AwfulHTMLResponseSerializer.h"

@implementation AwfulHTTPRequestOperationManager

- (id)initWithBaseURL:(NSURL *)URL
{
    self = [super initWithBaseURL:URL];
    if (!self) return nil;
    
    self.requestSerializer = [AwfulHTMLRequestSerializer new];
    self.requestSerializer.stringEncoding = NSWindowsCP1252StringEncoding;
    
    AwfulHTMLResponseSerializer *HTMLResponseSerializer = [AwfulHTMLResponseSerializer new];
    HTMLResponseSerializer.stringEncoding = NSWindowsCP1252StringEncoding;
    HTMLResponseSerializer.fallbackEncoding = NSISOLatin1StringEncoding;
    NSArray *responseSerializers = @[ [AFJSONResponseSerializer new],
                                      HTMLResponseSerializer ];
    self.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:responseSerializers];
    
    [self.reachabilityManager startMonitoring];
    
    return self;
}

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(AFHTTPRequestOperation *, id))success
                                                    failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure
{
    // NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time.
    // http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html
    // This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
    AFHTTPRequestOperation *operation = [super HTTPRequestOperationWithRequest:urlRequest
                                                                       success:success
                                                                       failure:failure];
    if ([urlRequest.HTTPMethod caseInsensitiveCompare:@"GET"] == NSOrderedSame) {
        [operation setCacheResponseBlock:^NSCachedURLResponse *(NSURLConnection *connection, NSCachedURLResponse *cachedResponse) {
            if (connection.currentRequest.cachePolicy == NSURLRequestUseProtocolCachePolicy) {
                NSHTTPURLResponse *response = (NSHTTPURLResponse *)cachedResponse.response;
                NSDictionary *headers = [response allHeaderFields];
                if (!(headers[@"Cache-Control"] || headers[@"Expires"])) {
                    NSLog(@"%s refusing to cache response to %@",__PRETTY_FUNCTION__, urlRequest.URL);
                    return nil;
                }
            }
            return cachedResponse;
        }];
    }
    return operation;
}

@end
