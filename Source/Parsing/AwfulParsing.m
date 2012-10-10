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

- (id)init
{
    return [self initWithHTMLData:nil];
}

@end

@interface UserParsedInfo ()

@property (copy, nonatomic) NSString *userID;

@property (copy, nonatomic) NSString *username;

@end

@implementation UserParsedInfo

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


@interface ReplyFormParsedInfo ()

@property (copy, nonatomic) NSString *formkey;

@property (copy, nonatomic) NSString *formCookie;

@property (copy, nonatomic) NSString *bookmark;

@end


@implementation ReplyFormParsedInfo

- (void)parseHTMLData
{
    NSString *htmlString = StringFromSomethingAwfulData(self.htmlData);
    NSData *utf8Data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *document = [[TFHpple alloc] initWithHTMLData:utf8Data];
    TFHppleElement *formkey = [document searchForSingle:@"//input[@name='formkey']"];
    self.formkey = [formkey objectForKey:@"value"];
    TFHppleElement *formCookie = [document searchForSingle:@"//input[@name='form_cookie']"];
    self.formCookie = [formCookie objectForKey:@"value"];
    TFHppleElement *bookmark = [document searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
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


@interface ForumHierarchyParsedInfo ()

@property (readonly, nonatomic) NSMutableArray *mutableCategories;

@end


@interface CategoryParsedInfo ()

@property (readonly, nonatomic) NSMutableArray *mutableForums;

@property (copy, nonatomic) NSString *name;

@property (copy, nonatomic) NSString *categoryID;

@end


@interface ForumParsedInfo ()

@property (weak, nonatomic) CategoryParsedInfo *category;

@property (readonly, nonatomic) NSMutableArray *mutableSubforums;

@property (weak, nonatomic) ForumParsedInfo *parentForum;

@property (copy, nonatomic) NSString *name;

@property (copy, nonatomic) NSString *forumID;

@end


@implementation ForumHierarchyParsedInfo

- (id)initWithHTMLData:(NSData *)htmlData
{
    self = [super initWithHTMLData:htmlData];
    if (self) {
        _mutableCategories = [NSMutableArray new];
    }
    return self;
}

- (void)parseHTMLData
{
    // There's a pulldown menu at the bottom of forumdisplay.php and showthread.php like this:
    //
    // <select name="forumid">
    //   <option value="-1">Whatever</option>
    //   <option value="pm">Private Messages</option>
    //   ...
    //   <option value="-1">--------------------</option>
    //   <option value="48"> Main</option>
    //   <option value="1">-- General Bullshit</option>
    //   <option value="155">---- SA's Front Page Discussion</option>
    //   ...
    // </select>
    //
    // This is the only place that lists *all* forums, so this is what we parse.
    NSError *error;
    NSRegularExpression *depthRegex = [NSRegularExpression regularExpressionWithPattern:@"^(-*) ?(.*)$"
                                                                                options:0
                                                                                  error:&error];
    if (!depthRegex) {
        NSLog(@"error creating depth regex: %@", error);
        return;
    }
    NSMutableArray *forumStack = [NSMutableArray new];
    TFHpple *document = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    NSArray *listOfItems = [document search:@"//select[@name='forumid']/option"];
    CategoryParsedInfo *currentCategory;
    for (TFHppleElement *item in listOfItems) {
        NSString *forumOrCategoryID = [item objectForKey:@"value"];
        if ([forumOrCategoryID integerValue] <= 0) continue;
        NSTextCheckingResult *match = [depthRegex firstMatchInString:[item content]
                                                        options:0
                                                          range:NSMakeRange(0, [[item content] length])];
        NSString *name = [[item content] substringWithRange:[match rangeAtIndex:2]];
        NSUInteger depth = [match rangeAtIndex:1].length / 2;
        if (depth == 0) {
            [forumStack removeAllObjects];
            currentCategory = [CategoryParsedInfo new];
            currentCategory.categoryID = forumOrCategoryID;
            currentCategory.name = name;
            [self.mutableCategories addObject:currentCategory];
        } else {
            while ([forumStack count] >= depth) {
                [forumStack removeLastObject];
            }
            ForumParsedInfo *forum = [ForumParsedInfo new];
            forum.name = name;
            forum.forumID = forumOrCategoryID;
            forum.category = currentCategory;
            if ([forumStack count] > 0) {
                ForumParsedInfo *parentForum = [forumStack lastObject];
                forum.parentForum = parentForum;
                [parentForum.mutableSubforums addObject:forum];
            } else {
                CategoryParsedInfo *category = [self.categories lastObject];
                [category.mutableForums addObject:forum];
            }
            [forumStack addObject:forum];
        }
    }
}

- (NSArray *)categories
{
    if ([self.mutableCategories count] == 0) [self parseHTMLData];
    return [self.mutableCategories copy];
}

@end


@implementation CategoryParsedInfo

- (id)initWithHTMLData:(NSData *)htmlData
{
    self = [super initWithHTMLData:htmlData];
    if (self) {
        _mutableForums = [NSMutableArray new];
    }
    return self;
}

- (NSArray *)forums
{
    return [self.mutableForums copy];
}

@end


@implementation ForumParsedInfo

- (id)initWithHTMLData:(NSData *)htmlData
{
    self = [super initWithHTMLData:htmlData];
    if (self) {
        _mutableSubforums = [NSMutableArray new];
    }
    return self;
}

- (NSArray *)subforums
{
    return [self.mutableSubforums copy];
}

@end
