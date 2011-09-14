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

@implementation SALR

+ (NSString *)config {
    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    
    [config setObject:[AwfulConfig username] forKey:@"username"];
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
