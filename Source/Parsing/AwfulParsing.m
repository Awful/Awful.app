//
//  AwfulParsing.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing.h"

@interface ParsedUserInfo ()

@property (copy, nonatomic) NSData *htmlData;

@property (copy, nonatomic) NSString *userID;

@property (copy, nonatomic) NSString *username;

@end

@implementation ParsedUserInfo

- (id)initWithHTMLData:(NSData *)html
{
    self = [super init];
    if (self) {
        _htmlData = [html copy];
    }
    return self;
}

- (void)parseHTMLData
{
    NSString *html = StringFromSomethingAwfulData(self.htmlData);
    if (!html) return;
    
    NSError *regex_error = nil;
    NSRegularExpression *userid_regex = [NSRegularExpression regularExpressionWithPattern:@"userid=(\\d+)" options:NSRegularExpressionCaseInsensitive error:&regex_error];
    
    if(regex_error != nil) {
        NSLog(@"%@", [regex_error localizedDescription]);
    }
    
    NSTextCheckingResult *userid_result = [userid_regex firstMatchInString:html
                                                                   options:0
                                                                     range:NSMakeRange(0, [html length])];
    NSRange userid_range = [userid_result rangeAtIndex:1];
    if (userid_range.location != NSNotFound) {
        NSString *user_id = [html substringWithRange:userid_range];
        int user_id_int = [user_id intValue];
        if (user_id_int != 0) {
            self.userID = user_id;
        }
    }
    
    NSRegularExpression *username_regex = [NSRegularExpression regularExpressionWithPattern:@"Edit Profile - (.*?)<" options:NSRegularExpressionCaseInsensitive error:&regex_error];
    
    if(regex_error != nil) {
        NSLog(@"%@", [regex_error localizedDescription]);
    }
    
    NSTextCheckingResult *username_result = [username_regex firstMatchInString:html
                                                                       options:0
                                                                         range:NSMakeRange(0, [html length])];
    NSRange username_range = [username_result rangeAtIndex:1];
    if (username_range.location != NSNotFound) {
        NSString *username = [html substringWithRange:username_range];
        self.username = [username stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
}

- (NSString *)userID
{
    if (!_userID) [self parseHTMLData];
    return _userID;
}

- (NSString *)username
{
    if (!_username) [self parseHTMLData];
    return _username;
}

@end
