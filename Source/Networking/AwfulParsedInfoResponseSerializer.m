//  AwfulParsedInfoResponseSerializer.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulParsedInfoResponseSerializer.h"

@implementation AwfulParsedInfoResponseSerializer

- (id)init
{
    if (!(self = [super init])) return nil;
    self.stringEncoding = NSWindowsCP1252StringEncoding;
    self.acceptableContentTypes = [NSSet setWithObjects:@"text/html", @"application/xhtml+xml", nil];
    return self;
}

#pragma mark - AFURLResponseSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    data = [super responseObjectForResponse:response data:data error:error];
    NSString *ugh = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
    // Sometimes it isn't windows-1252 and is actually what's sent in headers: ISO-8859-1.
    // Example: http://forums.somethingawful.com/showthread.php?threadid=2357406&pagenumber=2
    // Maybe it's just old posts; the example is from 2007. And we definitely get some mojibake,
    // but at least it's something.
    if (!ugh) {
        ugh = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
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
    NSError *regexError;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&regexError];
    if (!regex) {
        NSLog(@"error compiling semicolon-free entities regex: %@", regexError);
    }
    ugh = [regex stringByReplacingMatchesInString:ugh options:0 range:NSMakeRange(0, ugh.length) withTemplate:@"&$1;"];
    return self.parseBlock([ugh dataUsingEncoding:NSUTF8StringEncoding]);
}

@end
