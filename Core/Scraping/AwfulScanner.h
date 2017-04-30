//  AwfulScanner.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSScanner (AwfulScanner)

/// A scanner created with this method ignores no characters and is case sensitive.
+ (instancetype)awful_scannerWithString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
