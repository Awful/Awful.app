//
//  AwfulUser.h
//  Awful
//
//  Created by Nolan Waite on 12-12-28.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulUser.h"
@class ProfileParsedInfo;

@interface AwfulUser : _AwfulUser

+ (instancetype)userCreatedOrUpdatedFromProfileInfo:(ProfileParsedInfo *)profileInfo;

@end
