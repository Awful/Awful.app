//  AwfulProfileViewModel.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"

@interface AwfulProfileViewModel : NSObject

+ (id)newWithUser:(AwfulUser *)user;

@property (readonly, nonatomic) NSArray *contactInfo;

@end


extern NSString * const AwfulServiceHomepage;
extern NSString * const AwfulServicePrivateMessage;
