//
//  AwfulParsing.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing.h"

@interface ParsedInfo ()

@property (copy, nonatomic) NSData *htmlData;

@end

@implementation ParsedInfo

- (id)initWithHTMLData:(NSData *)htmlData
{
    self = [super init];
    if (self) {
        _htmlData = [htmlData copy];
    }
    return self;
}

@end

@interface ParsedUserInfo ()

@property (copy, nonatomic) NSString *userID;

@property (copy, nonatomic) NSString *username;

@end

@implementation ParsedUserInfo

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

- (void)applyToObject:(id)object
{
    NSDictionary *values = [self dictionaryWithValuesForKeys:@[ @"userID", @"username" ]];
    for (NSString *key in values) {
        id value = values[key];
        if (![value isEqual:[NSNull null]])
            [object setValue:value forKey:key];
    }
}

@end


@interface ParsedReplyFormInfo ()

@property (copy, nonatomic) NSString *formkey;

@property (copy, nonatomic) NSString *formCookie;

@property (copy, nonatomic) NSString *bookmark;

@end


@implementation ParsedReplyFormInfo

- (void)parseHTMLData
{
    NSString *htmlString = StringFromSomethingAwfulData(self.htmlData);
    NSData *utf8Data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *pageData = [[TFHpple alloc] initWithHTMLData:utf8Data];
    TFHppleElement *formkey = [pageData searchForSingle:@"//input[@name='formkey']"];
    self.formkey = [formkey objectForKey:@"value"];
    TFHppleElement *formCookie = [pageData searchForSingle:@"//input[@name='form_cookie']"];
    self.formCookie = [formCookie objectForKey:@"value"];
    TFHppleElement *bookmark = [pageData searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
    if (bookmark) {
        self.bookmark = [bookmark objectForKey:@"value"];
    }
}

- (NSString *)formkey
{
    if (!_formkey) [self parseHTMLData];
    return _formkey;
}

- (NSString *)formCookie
{
    if (!_formCookie) [self parseHTMLData];
    return _formCookie;
}

@end
