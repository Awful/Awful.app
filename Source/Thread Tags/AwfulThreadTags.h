//
//  AwfulThreadTags.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <AFNetworking/AFNetworking.h>

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
