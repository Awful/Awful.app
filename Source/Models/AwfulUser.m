//  AwfulUser.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulUser.h"
#import <HTMLReader/HTMLReader.h>
#import "HTMLNode+CachedSelector.h"

@implementation AwfulUser

@dynamic aboutMe;
@dynamic administrator;
@dynamic aimName;
@dynamic authorClasses;
@dynamic canReceivePrivateMessages;
@dynamic customTitleHTML;
@dynamic gender;
@dynamic homepageURL;
@dynamic icqName;
@dynamic idiotKing;
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
@dynamic posts;
@dynamic receivedPrivateMessages;
@dynamic sentPrivateMessages;
@dynamic singleUserThreadInfos;
@dynamic threads;

- (NSURL *)avatarURL
{
    if (self.customTitleHTML.length == 0) return nil;
    HTMLDocument *document = [HTMLDocument documentWithString:self.customTitleHTML];
    HTMLElement *avatarImage = ([document awful_firstNodeMatchingCachedSelector:@"div > img:first-child"] ?:
                                [document awful_firstNodeMatchingCachedSelector:@"body > img:first-child"] ?:
                                [document awful_firstNodeMatchingCachedSelector:@"a > img:first-child"]);
    return [NSURL URLWithString:avatarImage[@"src"]];
}

+ (NSSet *)keyPathsForValuesAffectingAvatarURL
{
    return [NSSet setWithObject:@"customTitle"];
}

+ (instancetype)firstOrNewUserWithUserID:(NSString *)userID
                                username:(NSString *)username
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(userID.length > 0 || username.length > 0);
    
    NSMutableArray *subpredicates = [NSMutableArray new];
    if (userID.length > 0) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"userID = %@", userID]];
    }
    if (username.length > 0) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"username = %@", username]];
    }
    NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
    AwfulUser *user = [AwfulUser fetchArbitraryInManagedObjectContext:managedObjectContext matchingPredicate:predicate];
    if (!user) {
        user = [AwfulUser insertInManagedObjectContext:managedObjectContext];
    }
    if (userID.length > 0) {
        user.userID = userID;
    }
    if (username.length > 0) {
        user.username = username;
    }
    return user;
}

@end
