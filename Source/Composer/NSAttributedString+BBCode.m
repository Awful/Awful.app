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
    return nil;
    
}

@end
