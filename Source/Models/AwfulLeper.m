#import "AwfulLeper.h"
#import "AwfulUser.h"
#import "AwfulParsing+Lepers.h"
#import "AwfulDataStack.h"


@interface AwfulLeper ()

// Private interface goes here.

@end


@implementation AwfulLeper

+ (NSArray*)lepersCreatedOrUpdatedWithParsedInfo:(NSArray *)info
{
    NSManagedObjectContext *moc = [[AwfulDataStack sharedDataStack] context];
    NSMutableDictionary *existingJerks = [NSMutableDictionary new];
    NSArray *banIDs = [info valueForKey:@"banID"];
    for (AwfulLeper *leper in [self fetchAllMatchingPredicate:@"banID IN %@", banIDs]) {
        existingJerks[leper.banID] = leper;
    }
    
    NSMutableArray *usernames;
    [usernames addObjectsFromArray:[info valueForKeyPath:@"bannedUserName"]];
    [usernames addObjectsFromArray:[info valueForKeyPath:@"modUserName"]];
    [usernames addObjectsFromArray:[info valueForKeyPath:@"adminUserName"]];

    
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    
    for (LepersParsedInfo *parsed in info) {
        AwfulLeper *leper = existingJerks[parsed.banID] ?: [AwfulLeper insertInManagedObjectContext:moc];
        [parsed applyToObject:leper];
        
        NSArray *types = @[@"jerk", @"mod", @"admin"];
        NSArray *ids = @[@"bannedUserID", @"modUserID", @"adminUserID"];
        for (uint i=0; i<types.count; i++)
        {
            NSString *userID = [parsed valueForKey:ids[i]];
            AwfulUser *user = existingUsers[userID];
            if (!user) user = [AwfulUser insertInManagedObjectContext:moc];
            [user setValue:existingUsers[userID] forKey:AwfulUserAttributes.userID];
            [user setValue:existingUsers[userID] forKey:AwfulUserAttributes.username];

            [leper setValue:user forKey:types[i]];
            
            existingJerks[leper.banID] = leper;
        }
        
    }
    
    [moc save:nil];
    return [existingJerks allValues];
}


@end
