//  AwfulHTMLRequestSerializer.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTMLRequestSerializer.h"

@implementation AwfulHTMLRequestSerializer

#pragma mark - AFURLRequestSerialization

- (NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request
                               withParameters:(NSDictionary *)parameters
                                        error:(NSError *__autoreleasing *)error
{
    if (![self.HTTPMethodsEncodingParametersInURI containsObject:request.HTTPMethod.uppercaseString]) {
        NSMutableDictionary *escapedParameters = [NSMutableDictionary dictionaryWithCapacity:parameters.count];
        for (id key in parameters) {
            NSString *value = parameters[key];
            if (![value isKindOfClass:[NSString class]]) {
                escapedParameters[key] = value;
            } else if ([value canBeConvertedToEncoding:self.stringEncoding]) {
                escapedParameters[key] = value;
            } else {
                escapedParameters[key] = StringByHTMLEscapingCharactersOutsideEncoding(value, self.stringEncoding);
            }
        }
        parameters = escapedParameters;
    }
    return [super requestBySerializingRequest:request withParameters:parameters error:error];
}

static NSString * StringByHTMLEscapingCharactersOutsideEncoding(NSString *input, NSStringEncoding encoding)
{
    NSCAssert(encoding == NSWindowsCP1252StringEncoding, @"can only handle win1252");
    NSMutableString *escaped = [NSMutableString new];
    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)input, &buffer, CFRangeMake(0, input.length));
    NSMutableData *buffer2 = [NSMutableData dataWithCapacity:input.length * sizeof(unichar)];
    void (^flush)(void) = ^{
        if (buffer2.length > 0) {
            CFStringAppendCharacters((__bridge CFMutableStringRef)escaped, buffer2.bytes, buffer2.length / sizeof(unichar));
            buffer2.length = 0;
        }
    };
    for (NSUInteger i = 0, end = input.length; i < end; i++) {
        unichar c = CFStringGetCharacterFromInlineBuffer(&buffer, i);
        if (CharacterIsInWin1252(c)) {
            [buffer2 appendBytes:&c length:sizeof(c)];
        } else {
            flush();
            UTF32Char longc = c;
            if (CFStringIsSurrogateHighCharacter(c) && i + 1 < end) {
                longc = CFStringGetLongCharacterForSurrogatePair(c, CFStringGetCharacterFromInlineBuffer(&buffer, ++i));
            }
            [escaped appendFormat:@"&#%u;", (unsigned int)longc];
        }
    }
    flush();
    return escaped;
}

static inline BOOL CharacterIsInWin1252(unichar c)
{
    // http://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt
    return (c <= 0x7f || c == 0x81 || c == 0x8d || c == 0x8f || c == 0x90 || c == 0x9d ||
            (c >= 0xa0 && c <= 0xff) || c == 0x0152 || c == 0x0153 || c == 0x0160 || c == 0x0161 ||
            c == 0x0178 || c == 0x017d || c == 0x017e || c == 0x0192 || c == 0x02c6 ||
            c == 0x02dc || c == 0x2013 || c == 0x2014 || (c >= 0x2018 && c <= 0x201a) ||
            (c >= 0x201c && c <= 0x201e) || (c >= 0x2020 && c <= 0x2022) || c == 0x2026 ||
            c == 0x2030 || c == 0x2039 || c == 0x203a || c == 0x20ac || c == 0x2122);
}

@end
