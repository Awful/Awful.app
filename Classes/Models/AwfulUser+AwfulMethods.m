//
//  AwfulUser+AwfulMethods.m
//  Awful
//
//  Created by Sean Berry on 3/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUser+AwfulMethods.h"

@implementation AwfulUser (AwfulMethods)

+(AwfulUser *)currentUser
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[AwfulUser entityName]];
    NSError *err = nil;
    NSArray *results = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&err];
    if(err != nil) {
        NSLog(@"failed to fetch AwfulUser %@", [err localizedDescription]);
    }
    
    AwfulUser *user = nil;
    if([results count] > 0) {
        user = [results objectAtIndex:0];
    } else {
        user = [AwfulUser insertInManagedObjectContext:ApplicationDelegate.managedObjectContext];
        user.postsPerPageValue = 40;
    }
    return user;
}

@end
