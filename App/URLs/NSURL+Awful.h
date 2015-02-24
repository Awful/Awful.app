//  NSURL+Awful.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

@interface NSURL (Awful)

// Returns the equivalent awful:// URL, or nil if there is no such thing.
- (instancetype)awfulURL;

@end
