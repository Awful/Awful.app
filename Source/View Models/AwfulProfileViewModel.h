//
//  AwfulProfileViewModel.h
//  Awful
//
//  Created by Nolan Waite on 2013-06-04.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AwfulModels.h"

@interface AwfulProfileViewModel : NSObject

+ (id)newWithUser:(AwfulUser *)user;

@property (readonly, nonatomic) NSArray *contactInfo;

@end


extern NSString * const AwfulServiceHomepage;
extern NSString * const AwfulServicePrivateMessage;
