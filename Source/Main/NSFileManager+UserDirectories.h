//
//  NSFileManager+UserDirectories.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-31.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (UserDirectories)

- (NSURL *)cachesDirectory;

- (NSURL *)documentDirectory;

@end
