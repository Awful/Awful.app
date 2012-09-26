//
//  AwfulUser.m
//  Awful
//
//  Created by Nolan Waite on 2012-09-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUser.h"

@implementation AwfulUser

+ (AwfulUser *)userWithDictionaryRepresentation:(NSDictionary *)dictionary
{
    AwfulUser *user = [self new];
    [user setValuesForKeysWithDictionary:dictionary];
    return user;
}

- (NSDictionary *)dictionaryRepresentation
{
    return [self dictionaryWithValuesForKeys:@[@"userName", @"userID"]];
}

@end
