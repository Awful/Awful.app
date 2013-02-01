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
    
    NSMutableArray *usernames = [NSMutableArray new];
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
        NSArray *ids = @[@"banned", @"mod", @"admin"];
        for (uint i=0; i<types.count; i++)
        {
            NSString *idKey = [ids[i] stringByAppendingString:@"UserID"];
            NSString *NameKey = [ids[i] stringByAppendingString:@"UserName"];
            
            NSString *userID = [parsed valueForKey:idKey];
            AwfulUser *user = existingUsers[userID];
            if (!user) user = [AwfulUser insertInManagedObjectContext:moc];
            
            [user setValue:[parsed valueForKey:idKey] forKey:AwfulUserAttributes.userID];
            [user setValue:[parsed valueForKey:NameKey] forKey:AwfulUserAttributes.username];

            [leper setValue:user forKey:types[i]];
        }
        existingJerks[leper.banID] = leper;
        
    }
    
    [moc save:nil];
    return [existingJerks allValues];
}


@end
