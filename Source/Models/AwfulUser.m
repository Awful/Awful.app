//  AwfulUser.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulUser.h"
#import "GTMNSString+HTML.h"
#import "TFHpple.h"

@implementation AwfulUser

@dynamic aboutMe;
@dynamic administrator;
@dynamic aimName;
@dynamic canReceivePrivateMessages;
@dynamic customTitleHTML;
@dynamic gender;
@dynamic homepageURL;
@dynamic icqName;
@dynamic interests;
@dynamic lastPost;
@dynamic location;
@dynamic moderator;
@dynamic occupation;
@dynamic postCount;
@dynamic postRate;
@dynamic profilePictureURL;
@dynamic regdate;
@dynamic userID;
@dynamic username;
@dynamic yahooName;
@dynamic editedPosts;
@dynamic posts;
@dynamic receivedPrivateMessages;
@dynamic sentPrivateMessages;
@dynamic singleUserThreadInfos;
@dynamic threads;

- (NSURL *)avatarURL
{
    if (self.customTitleHTML.length == 0) return nil;
    NSData *data = [self.customTitleHTML dataUsingEncoding:NSUTF8StringEncoding];
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
                             inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulUser *user = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                         matchingPredicateFormat:@"userID = %@", profileInfo.userID];
    if (!user) user = [AwfulUser insertInManagedObjectContext:managedObjectContext];
    [profileInfo applyToObject:user];
    user.homepageURL = profileInfo.homepage;
    user.profilePictureURL = profileInfo.profilePicture;
    return user;
}

+ (instancetype)firstOrNewUserWithUserID:(NSString *)userID
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulUser *user = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                         matchingPredicateFormat:@"userID = %@", userID];
    if (!user) {
        user = [AwfulUser insertInManagedObjectContext:managedObjectContext];
        user.userID = userID;
    }
    return user;
}

@end
