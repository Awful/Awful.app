//
//  AwfulUser.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "_AwfulUser.h"

@interface AwfulUser : _AwfulUser

@property (readonly, nonatomic) NSURL *avatarURL;

// Does not save the managed object context.
+ (instancetype)userCreatedOrUpdatedFromJSON:(NSDictionary *)json;

@end
