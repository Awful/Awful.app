//
//  AwfulUser.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulUser.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"
#import "GTMNSString+HTML.h"
#import "NSManagedObject+Awful.h"
#import "TFHpple.h"

@implementation AwfulUser

- (NSURL *)avatarURL
{
    if ([self.customTitle length] == 0) return nil;
    NSData *data = [self.customTitle dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *html = [[TFHpple alloc] initWithHTMLData:data];
    // The avatar is an image that's the first child of its parent, which is either a <div>, an
    // <a>, or the implied <body>.
    TFHppleElement *avatar = [html searchForSingle:@"//img[count(preceding-sibling::*) = 0 and (parent::div or parent::body or parent::a)]"];
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
