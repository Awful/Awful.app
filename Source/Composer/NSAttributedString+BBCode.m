//
//  NSAttributedString+BBCode.m
//  Awful
//
//  Created by me on 1/19/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "NSAttributedString+BBCode.h"

#define FONT_DEFAULT [UIFont systemFontOfSize:17]
#define FONT_BOLD [UIFont boldSystemFontOfSize:17]
#define FONT_ITALIC [UIFont italicSystemFontOfSize:17]

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
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                             kAwfulFormatTagKey: tag}
                                 ];

    if ([tag isEqualToString:@"b"]) {
        [dict setObject:FONT_BOLD
                 forKey:NSFontAttributeName];
    }
    else if ([tag isEqualToString:@"i"]) {
        [dict setObject:FONT_ITALIC
                 forKey:NSFontAttributeName];
    }
    else if ([tag isEqualToString:@"u"]) {
        [dict addEntriesFromDictionary:@{
                   NSFontAttributeName: FONT_DEFAULT,
                   NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSUnderlineStyleSingle]}
         ];
    }
    else if ([tag isEqualToString:@"s"]) {
        [dict addEntriesFromDictionary:@{
                    NSFontAttributeName: FONT_DEFAULT,
                    NSStrikethroughStyleAttributeName:[NSNumber numberWithInt:1]}
         ];
    }
    else if ([tag isEqualToString:@"spoiler"]) {
        [dict addEntriesFromDictionary:@{
                    NSFontAttributeName: FONT_DEFAULT,
                    NSBackgroundColorAttributeName:[UIColor blackColor],
                    NSForegroundColorAttributeName:[UIColor whiteColor]}
         ];
    }
    
    return dict;
}

@end
