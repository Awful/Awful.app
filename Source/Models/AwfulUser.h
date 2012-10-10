//
//  AwfulUser.h
//  Awful
//
//  Created by Nolan Waite on 2012-09-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulUser : NSObject

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSString *userID;

+ (AwfulUser *)userWithDictionaryRepresentation:(NSDictionary *)dictionary;

- (NSDictionary *)dictionaryRepresentation;

@end
