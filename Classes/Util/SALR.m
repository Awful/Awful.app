//
//  SALR.m
//  Awful
//
//  Created by Scott Ferguson on 9/14/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulConfig.h"
#import "SALR.h"
#import "SBJson.h"
#import "AwfulNavigator.h"
#import "AwfulUser.h"

@implementation SALR

+ (NSString *)config {
    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    
    AwfulNavigator *nav = getNavigator();
    
    [config setObject:nav.user.userName forKey:@"username"];
    [config setObject:[AwfulConfig highlightOwnMentions] forKey:@"highlightUsername"];
    [config setObject:[AwfulConfig highlightOwnQuotes] forKey:@"highlightUserQuote"];
    [config setObject:@"#a2cd5a" forKey:@"userQuote"];
    [config setObject:@"#9933ff" forKey:@"usernameHighlight"];

    SBJsonWriter *jsonWriter = [SBJsonWriter new];
    NSString *result = [jsonWriter stringWithObject:config];
    
    [config release];
    
    return result;
}

@end
