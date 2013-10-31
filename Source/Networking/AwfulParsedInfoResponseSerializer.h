//  AwfulParsedInfoResponseSerializer.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AFURLResponseSerialization.h"

/**
 * An AwfulParsedInfoResponseSerializer vends various *ParsedInfo classes
 */
@interface AwfulParsedInfoResponseSerializer : AFHTTPResponseSerializer

/**
 * A block that takes as its sole parameter an HTML document formatted as a utf8 string and returns some kind of parsed info.
 */
@property (copy, nonatomic) id(^parseBlock)(NSData *data);

@end
