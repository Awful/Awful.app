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
#import "NSManagedObject+Awful.h"
#import "TFHpple.h"

@implementation AwfulUser

//- (NSURL *)avatarURL
//{
//    if ([self.customTitle length] == 0) return nil;
//    NSData *data = [self.customTitle dataUsingEncoding:NSUTF8StringEncoding];
//    TFHpple *html = [[TFHpple alloc] initWithHTMLData:data];
//    // The avatar is an image that's the first child of its parent, which is either a <div>, an
//    // <a>, or the implied <body>.
//    TFHppleElement *avatar = [html searchForSingle:@"//img[count(preceding-sibling::*) = 0 and (parent::div or parent::body or parent::a)]"];
//    NSString *src = [avatar objectForKey:@"src"];
//    if ([src length] == 0) return nil;
//    return [NSURL URLWithString:src];
//}

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

+ (instancetype)userCreatedOrUpdatedFromJSON:(NSDictionary *)json
{
    NSString *userID = [json[@"userid"] stringValue];
    if (!userID) return nil;
    AwfulUser *user = [self firstMatchingPredicate:@"userID = %@", userID];
    if (!user) {
        user = [self insertNew];
        user.userID = userID;
    }
    user.username = Stringify(json[@"username"]);
    
    // Everything else is optional.
    if (json[@"aim"]) user.aimName = StringOrNilIfEmpty(json[@"aim"]);
    if (json[@"biography"]) user.aboutMe = StringOrNilIfEmpty(json[@"biography"]);
    if (json[@"gender"]) {
        if ([json[@"gender"] isEqual:@"F"]) user.gender = @"female";
        else if ([json[@"gender"] isEqual:@"M"]) user.gender = @"male";
        else user.gender = @"porpoise";
    }
    if (json[@"homepage"]) user.homepageURL = StringOrNilIfEmpty(json[@"homepage"]);
    if (json[@"icq"]) user.icqName = StringOrNilIfEmpty(json[@"icq"]);
    if (json[@"interests"]) user.interests = StringOrNilIfEmpty(json[@"interests"]);
    if (json[@"joindate"]) {
        user.regdate = [NSDate dateWithTimeIntervalSince1970:[json[@"joindate"] doubleValue]];
    }
    if (json[@"lastpost"]) {
        user.lastPost = [NSDate dateWithTimeIntervalSince1970:[json[@"lastpost"] doubleValue]];
    }
    if (json[@"location"]) user.location = StringOrNilIfEmpty(json[@"location"]);
    if (json[@"occupation"]) user.occupation = StringOrNilIfEmpty(json[@"occupation"]);
    if (json[@"picture"]) user.profilePictureURL = StringOrNilIfEmpty(json[@"picture"]);
    if (json[@"posts"]) user.postCount = json[@"posts"];
    if (json[@"postsperday"]) user.postRate = [json[@"postsperday"] stringValue];
    if (json[@"role"]) {
        user.administratorValue = [json[@"role"] isEqual:@"A"];
        user.moderatorValue = [json[@"role"] isEqual:@"M"];        
    }
    if (json[@"usertitle"]) user.customTitle = json[@"usertitle"];
    if (json[@"yahoo"]) user.yahooName = StringOrNilIfEmpty(json[@"yahoo"]);
    
    [[AwfulDataStack sharedDataStack] save];
    return user;
}

static id StringOrNilIfEmpty(const id obj)
{
    if (!obj || [obj isEqual:[NSNull null]]) return nil;
    if ([obj respondsToSelector:@selector(length)] && [obj length] == 0) return nil;
    return Stringify(obj);
}

static NSString * Stringify(const id obj)
{
    if (!obj || [obj isEqual:[NSNull null]]) return obj;
    if ([obj isKindOfClass:[NSString class]]) return obj;
    if ([obj respondsToSelector:@selector(stringValue)]) return [obj stringValue];
    return [obj description];
}

@end
