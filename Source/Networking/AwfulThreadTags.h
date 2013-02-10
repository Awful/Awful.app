//
//  AwfulThreadTags.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-23.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AFNetworking.h"

@interface AwfulThreadTags : AFHTTPClient

// Singleton instance.
+ (AwfulThreadTags *)sharedThreadTags;

// Get the the Awful-style thread tag for a filename. If it wasn't shipped with this version, try to
// download it.
//
// Sends AwfulNewThreadTagsAvailableNotification when new tags are downloaded.
//
// Returns the image if found, or nil on failure.
- (UIImage *)threadTagNamed:(NSString *)threadTagName;

@end


// Sent when new thread tags are downloaded.
//
// The notification's object is a collection of thread tag names that responds to -containsObject:.
extern NSString * const AwfulNewThreadTagsAvailableNotification;

@interface UIImage (AwfulThreadTags)
+ (UIImage*) threadTagNamed:(NSString*)name;
@end
