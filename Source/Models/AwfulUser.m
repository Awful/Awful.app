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
#import "TFHpple.h"

@implementation AwfulUser

- (NSURL *)avatarURL
{
    if ([self.customTitle length] == 0) return nil;
    NSData *data = [self.customTitle dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *html = [[TFHpple alloc] initWithHTMLData:data];
    // The avatar is an image that's the first child of its parent, which is either a <div> or the
    // implied <body>.
    TFHppleElement *avatar = [html searchForSingle:@"//img[count(preceding-sibling::*) = 0 and (parent::div or parent::body)]"];
    NSString *src = [avatar objectForKey:@"src"];
    if ([src length] == 0) return nil;
    return [NSURL URLWithString:src];
}

+ (NSSet *)keyPathsForValuesAffectingAvatarURL
{
    return [NSSet setWithObject:@"customTitle"];
}

+ (instancetype)userCreatedOrUpdatedFromProfileInfo:(ProfileParsedInfo *)profileInfo
{
    AwfulUser *user = [self firstMatchingPredicate:@"userID = %@", profileInfo.userID];
    if (!user) user = [AwfulUser insertNew];
    [profileInfo applyToObject:user];
    user.homepageURL = [profileInfo.homepage absoluteString];
    user.profilePictureURL = [profileInfo.profilePicture absoluteString];
    [[AwfulDataStack sharedDataStack] save];
    return user;
}

@end
