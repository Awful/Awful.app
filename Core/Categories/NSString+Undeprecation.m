//
//  NSString+Undeprecation.m
//  Awful
//
//  Created by Nolan Waite on 2016-12-24.
//  Copyright © 2016 Awful Contributors. All rights reserved.
//

#import "NSString+Undeprecation.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSString (Undeprecation)

- (instancetype)awful_stringByAddingPercentEncodingAllowingCharactersInString:(nullable NSString *)allowedCharacters escapingAdditionalCharactersInString:(nullable NSString *)disallowedCharacters encoding:(NSStringEncoding)encoding
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(nil, (CFStringRef)self, (CFStringRef)allowedCharacters, (CFStringRef)disallowedCharacters, CFStringConvertNSStringEncodingToEncoding(encoding)));
    
    #pragma clang diagnostic pop
}

@end

NS_ASSUME_NONNULL_END
