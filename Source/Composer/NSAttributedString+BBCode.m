//
//  NSAttributedString+BBCode.m
//  Awful
//
//  Created by me on 1/19/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "NSAttributedString+BBCode.h"

@implementation NSAttributedString (BBCode)

+ (NSAttributedString*)attributedStringWithBBCodeString:(NSString *)bbCodeString
{
    /*
    NSString *pattern = @"\\[[a-z*?\\].*?\\[/$1\\]";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    
    //NSArray *matches = [regex matchesInString:bbCodeString options:0
                                        range:NSMakeRange(0, bbCodeString.length)];
    */
    
    return [[NSAttributedString alloc] initWithString:bbCodeString attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:14]}];
    
    
}

- (NSString*)BBCode {
    NSMutableString *s = [self.string mutableCopy];
    
    __block int modifier = 0;
    [self enumerateAttributesInRange:NSMakeRange(0, self.length)
                             options:0
                          usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
                              
                              if (attrs[kAwfulFormatTagKey]) {
                                  NSString *tagged = [NSString stringWithFormat:@"[%@]%@[/%@]",
                                                      attrs[kAwfulFormatTagKey],
                                                      [self.string substringWithRange:range],
                                                      attrs[kAwfulFormatTagKey]];
                                  
                                  NSRange adjustedRange = NSMakeRange(range.location+modifier,
                                                                      range.length);
                                  
                                  [s replaceCharactersInRange:adjustedRange
                                                   withString:tagged];
                                  
                                  //lengthening the string, so need to keep adjusting ranges
                                  modifier += tagged.length - range.length;
                              }
                          }];
    return s;
    
}

@end

@implementation NSDictionary (AwfulAttributedString)

+ (NSDictionary*)attributeDictionaryWithTag:(NSString *)tag {
    NSMutableDictionary *dict = [NSMutableDictionary new];

    if ([tag isEqualToString:@"b"]) {
        [dict setObject:[UIFont boldSystemFontOfSize:17]
                 forKey:NSFontAttributeName];
    }
    else if ([tag isEqualToString:@"i"]) {
        [dict setObject:[UIFont italicSystemFontOfSize:17]
                 forKey:NSFontAttributeName];
    }
    else if ([tag isEqualToString:@"u"]) {
        [dict setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle]
                 forKey:NSUnderlineStyleAttributeName];
    }
    
    [dict setObject:tag forKey:kAwfulFormatTagKey];
    
    return dict;
}

@end
