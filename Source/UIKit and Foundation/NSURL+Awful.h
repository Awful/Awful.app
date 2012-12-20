//
//  NSURL+Awful.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (Awful)

// Returns the equivalent awful:// URL, or nil if there is no such thing.
- (NSURL *)awfulURL;

@end
