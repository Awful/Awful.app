//
//  SALR.m
//  Awful
//
//  Created by Scott Ferguson on 9/14/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "SALR.h"
#import "AwfulSettings.h"

@implementation SALR

+ (NSString *)config
{
    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    AwfulUser *user = AwfulSettings.settings.currentUser;
    if(user.username != nil) {
        [config setObject:user.username forKey:@"username"];
    } else {
        return @"";
    }
    [config setObject:[[AwfulSettings settings] highlightOwnMentions] ? @"true" : @"false"
               forKey:@"highlightUsername"];
    [config setObject:[[AwfulSettings settings] highlightOwnQuotes] ? @"true" : @"false"
               forKey:@"highlightUserQuote"];
    [config setObject:@"#a2cd5a" forKey:@"userQuote"];
    [config setObject:@"#9933ff" forKey:@"usernameHighlight"];
    
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:config options:0 error:&error];
    if (!data)
    {
        NSLog(@"error serializing SALR config %@ (error %@)", config, error);
        return @"";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
