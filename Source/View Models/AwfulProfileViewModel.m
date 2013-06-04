//
//  AwfulProfileViewModel.m
//  Awful
//
//  Created by Nolan Waite on 2013-06-04.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulProfileViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulSettings.h"

@interface AwfulProfileViewModel ()

@property (nonatomic) AwfulUser *user;

@end


@implementation AwfulProfileViewModel

+ (id)newWithUser:(AwfulUser *)user
{
    AwfulProfileViewModel *viewModel = [self new];
    viewModel.user = user;
    return viewModel;
}

- (NSDateFormatter *)regDateFormat
{
    return AwfulDateFormatters.formatters.regDateFormatter;
}

- (NSDateFormatter *)lastPostDateFormat
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = self.regDateFormat.locale;
    formatter.dateFormat = @"MMM d, yyyy HH:mm";
    return formatter;
}

- (NSArray *)contactInfo
{
    NSMutableArray *contactInfo = [NSMutableArray new];
    if (self.user.canReceivePrivateMessagesValue)
    if ([AwfulSettings settings].canSendPrivateMessages) {
        [contactInfo addObject:@{
             @"service": AwfulServicePrivateMessage,
             @"address": self.user.username,
         }];
    }
    if ([self.user.aimName length] > 0) {
        [contactInfo addObject:@{ @"service": @"AIM", @"address": self.user.aimName }];
    }
    if ([self.user.icqName length] > 0) {
        [contactInfo addObject:@{ @"service": @"ICQ", @"address": self.user.icqName }];
    }
    if ([self.user.yahooName length] > 0) {
        [contactInfo addObject:@{ @"service": @"Yahoo!", @"address": self.user.yahooName }];
    }
    if ([self.user.homepageURL length] > 0) {
        [contactInfo addObject:@{
             @"service": AwfulServiceHomepage,
             @"address": self.user.homepageURL,
         }];
    }
    return contactInfo;
}

- (NSArray *)additionalInfo
{
    NSMutableArray *additionalInfo = [NSMutableArray new];
    if ([self.user.location length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Location", @"info": self.user.location }];
    }
    if ([self.user.interests length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Interests", @"info": self.user.interests }];
    }
    if ([self.user.occupation length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Occupation", @"info": self.user.occupation }];
    }
    return additionalInfo;
}

- (NSString *)customTitle
{
    if ([self.user.customTitle isEqualToString:@"<br/>"]) {
        return nil;
    }
    return self.user.customTitle;
}

- (NSString *)gender
{
    return self.user.gender ?: @"porpoise";
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.user valueForKey:key];
}

@end


NSString * const AwfulServiceHomepage = @"Homepage";
NSString * const AwfulServicePrivateMessage = @"Private Message";
