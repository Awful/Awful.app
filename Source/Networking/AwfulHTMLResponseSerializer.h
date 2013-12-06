//  AwfulHTMLResponseSerializer.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AFURLResponseSerialization.h"
#import <HTMLReader/HTMLReader.h>

/**
 * An AwfulHTMLResponseSerializer turns HTTP responses into HTML documents.
 */
@interface AwfulHTMLResponseSerializer : AFHTTPResponseSerializer

/**
 * If data cannot be decoded using stringEncoding, the fallbackEncoding is then tried. Default is 0 meaning "no fallback".
 */
@property (assign, nonatomic) NSStringEncoding fallbackEncoding;

@end
