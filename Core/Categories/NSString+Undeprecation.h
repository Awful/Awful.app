//  NSString+Undeprecation.h
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Undeprecation)

/// Percent-encoding methods that take an `NSStringEncoding` parameter were all deprecated, and rightfully so, except it just so happens that we need that functionality. Here we expose it to Swift.
- (instancetype)awful_stringByAddingPercentEncodingAllowingCharactersInString:(nullable NSString *)allowedCharacters escapingAdditionalCharactersInString:(nullable NSString *)disallowedCharacters encoding:(NSStringEncoding)encoding;

@end

NS_ASSUME_NONNULL_END
