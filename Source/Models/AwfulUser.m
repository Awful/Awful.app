//
//  AwfulUser.m
//  Awful
//
//  Created by Nolan Waite on 12-12-28.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUser.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"

@implementation AwfulUser

+ (instancetype)userCreatedOrUpdatedFromProfileInfo:(ProfileParsedInfo *)profileInfo
{
    AwfulUser *user = [self firstMatchingPredicate:@"userID = %@", profileInfo.userID];
    if (!user) user = [AwfulUser insertNew];
    [profileInfo applyToObject:user];
    user.avatarURL = [profileInfo.avatar absoluteString];
    user.homepageURL = [profileInfo.homepage absoluteString];
    user.profilePictureURL = [profileInfo.profilePicture absoluteString];
    [[AwfulDataStack sharedDataStack] save];
    return user;
}

@end
