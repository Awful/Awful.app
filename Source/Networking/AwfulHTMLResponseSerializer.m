//  AwfulHTMLResponseSerializer.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTMLResponseSerializer.h"
#import "AwfulErrorDomain.h"

@implementation AwfulHTMLResponseSerializer

- (id)init
{
    if (!(self = [super init])) return nil;
    self.acceptableContentTypes = [NSSet setWithObjects:@"text/html", @"application/xhtml+xml", nil];
    return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    data = [super responseObjectForResponse:response data:data error:error];
    NSString *string = [[NSString alloc] initWithData:data encoding:self.stringEncoding];
    if (!string && self.fallbackEncoding) {
        string = [[NSString alloc] initWithData:data encoding:self.fallbackEncoding];
    }
    if (!string) {
        if (error) {
            *error = [NSError errorWithDomain:AwfulErrorDomain
                                         code:AwfulErrorCodes.parseError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Parsing failed; string could not be decoded",
                                                 NSURLErrorFailingURLErrorKey: response.URL }];
        }
        return nil;
    }
    return [HTMLDocument documentWithString:string];
}

@end
