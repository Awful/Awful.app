//
//  NSFileManager+UserDirectories.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <Foundation/Foundation.h>

@interface NSFileManager (UserDirectories)

- (NSURL *)cachesDirectory;

- (NSURL *)documentDirectory;

@end
