//  AwfulJSONOrScrapeOperation.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulJSONOrScrapeOperation.h"

@interface AwfulJSONOrScrapeOperation ()

@property (nonatomic) id responseJSON;

@property (nonatomic) id responseParsedInfo;

@property (nonatomic) NSError *JSONError;

@end


// This basically reimplements AFJSONRequestOperation because I couldn't figure out a smart way to
// subclass it or otherwise borrow its functionality.
@implementation AwfulJSONOrScrapeOperation

+ (dispatch_queue_t)processingQueue
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.awfulapp.Awful.parse-json-or-scrape", 0);
    });
    return queue;
}

- (id)responseJSON
{
    if (_responseJSON) return _responseJSON;
    if (![[self.response MIMEType] isEqualToString:@"application/json"]) return nil;
    if ([self.responseData length] == 0) return nil;
    NSData *JSONData = [self.responseString dataUsingEncoding:self.responseStringEncoding];
    NSError *error = nil;
    self.responseJSON = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&error];
    if (!self.responseJSON) self.JSONError = error;
    return _responseJSON;
}

- (NSError *)error
{
    return self.JSONError ?: [super error];
}

#pragma mark - AFHTTPRequestOperation

+ (BOOL)canProcessRequest:(NSURLRequest *)urlRequest
{
    return YES;
}

- (void)setCompletionBlockWithSuccess:(void (^)(AFHTTPRequestOperation *, id))success
                              failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-retain-cycles"
    self.completionBlock = ^{
        if (self.error) {
            if (failure) {
                dispatch_async(self.failureCallbackQueue ?: dispatch_get_main_queue(), ^{
                    failure(self, self.error);
                });
            }
            return;
        }
        dispatch_async([[self class] processingQueue], ^{
            id JSON = self.responseJSON;
            if (self.JSONError) {
                dispatch_async(self.failureCallbackQueue ?: dispatch_get_main_queue(), ^{
                    failure(self, self.error);
                });
                return;
            }
            if (!JSON && self.createParsedInfoBlock) {
                NSData *UTF8Data = ConvertFromWindows1252ToUTF8AndFixXMLParserGarbage(self.responseData);
                self.responseParsedInfo = self.createParsedInfoBlock(UTF8Data);
            }
            if (success) {
                dispatch_async(self.successCallbackQueue ?: dispatch_get_main_queue(), ^{
                    success(self, JSON ?: self.responseParsedInfo);
                });
            }
        });
    };
    #pragma clang diagnostic pop
}

static NSData *ConvertFromWindows1252ToUTF8AndFixXMLParserGarbage(NSData *windows1252)
{
    NSString *ugh = [[NSString alloc] initWithData:windows1252
                                          encoding:NSWindowsCP1252StringEncoding];
    // Sometimes it isn't windows-1252 and is actually what's sent in headers: ISO-8859-1.
    // Example: http://forums.somethingawful.com/showthread.php?threadid=2357406&pagenumber=2
    // Maybe it's just old posts; the example is from 2007. And we definitely get some mojibake,
    // but at least it's something.
    if (!ugh) {
        ugh = [[NSString alloc] initWithData:windows1252 encoding:NSISOLatin1StringEncoding];
    }
    
    // HTML parses some entities without semicolons. libxml will simply escape the ampersand.
    NSString *pattern = (@"&(Aacute|aacute|Acirc|acirc|acute|AElig|aelig|Agrave|agrave|AMP|amp|"
                         @"Aring|aring|Atilde|atilde|Auml|auml|brvbar|Ccedil|ccedil|cedil|cent|"
                         @"COPY|copy|curren|deg|divide|Eacute|eacute|Ecirc|ecirc|Egrave|egrave|"
                         @"ETH|eth|Euml|euml|frac12|frac14|frac34|GT|gt|Iacute|iacute|Icirc|"
                         @"icirc|iexcl|Igrave|igrave|iquest|Iuml|iuml|laquo|LT|lt|macr|micro|"
                         @"middot|nbsp|not|Ntilde|ntilde|Oacute|oacute|Ocirc|ocirc|Ograve|ograve|"
                         @"ordf|ordm|Oslash|oslash|Otilde|otilde|Ouml|ouml|para|plusmn|pound|"
                         @"QUOT|quot|raquo|REG|reg|sect|shy|sup1|sup2|sup3|szlig|THORN|thorn|"
                         @"times|Uacute|uacute|Ucirc|ucirc|Ugrave|ugrave|uml|Uuml|uuml|Yacute|"
                         @"yacute|yen|yuml)(?!;)");
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error compiling semicolon-free entities regex: %@", error);
    }
    ugh = [regex stringByReplacingMatchesInString:ugh options:0
                                            range:NSMakeRange(0, [ugh length])
                                     withTemplate:@"&$1;"];
    
    return [ugh dataUsingEncoding:NSUTF8StringEncoding];
}

@end
