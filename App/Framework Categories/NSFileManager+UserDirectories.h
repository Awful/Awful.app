//  NSFileManager+UserDirectories.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

@interface NSFileManager (UserDirectories)

/// A subdirectory in the Application Support directory named after the main bundle identifier.
@property (readonly, nonatomic) NSURL *applicationSupportDirectory;

/// The caches directory that iOS may empty when the application is not running.
@property (readonly, nonatomic) NSURL *cachesDirectory;

/// The document directory visible from iTunes.
@property (readonly, nonatomic) NSURL *documentDirectory;

@end
