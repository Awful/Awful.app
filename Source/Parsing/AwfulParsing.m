//
//  AwfulParsing.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing.h"
#import "AwfulThread+AwfulMethods.h"

@interface ParsedInfo ()

@property (copy, nonatomic) NSData *htmlData;

@end

@implementation ParsedInfo

- (id)initWithHTMLData:(NSData *)htmlData
{
    self = [super init];
    if (self) {
        _htmlData = [htmlData copy];
        [self parseHTMLData];
    }
    return self;
}

- (id)init
{
    return [self initWithHTMLData:nil];
}

- (void)parseHTMLData
{
    [NSException raise:NSInternalInconsistencyException
                format:@"subclasses must implement %@", NSStringFromSelector(_cmd)];
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

- (void)parseHTMLData
{
    _mutableCategories = [NSMutableArray new];
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
    return [self.mutableCategories copy];
}

@end


@implementation CategoryParsedInfo

- (void)parseHTMLData
{
    _mutableForums = [NSMutableArray new];
}

- (NSArray *)forums
{
    return [self.mutableForums copy];
}

@end


@implementation ForumParsedInfo

- (void)parseHTMLData
{
    _mutableSubforums = [NSMutableArray new];
}

- (NSArray *)subforums
{
    return [self.mutableSubforums copy];
}

@end


@interface ThreadParsedInfo ()

@property (copy, nonatomic) NSString *forumID;

@property (copy, nonatomic) NSString *threadID;

@property (copy, nonatomic) NSString *title;

@property (nonatomic) BOOL sticky;

@property (nonatomic) NSURL *threadIconImageURL;

@property (nonatomic) NSURL *threadIconImageURL2;

@property (copy, nonatomic) NSString *authorName;

@property (nonatomic) BOOL seen;

@property (nonatomic) BOOL isLocked;

@property (nonatomic) NSInteger starCategory;

@property (nonatomic) NSInteger totalUnreadPosts;

@property (nonatomic) NSInteger totalReplies;

@property (nonatomic) NSInteger threadVotes;

@property (nonatomic) NSDecimalNumber *threadRating;

@property (copy, nonatomic) NSString *lastPostAuthorName;

@property (nonatomic) NSDate *lastPostDate;

@end


@implementation ThreadParsedInfo

+ (NSArray *)threadsWithHTMLData:(NSData *)htmlData
{
    // The breadcrumbs tell us what forum we're in!
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:htmlData];
    NSString *forumID;
    TFHppleElement *forum = [doc searchForSingle:@"(//div[" HAS_CLASS(breadcrumbs) "]//a[contains(@href, 'forumid')])[last()]"];
    if (forum) {
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"forumid=(\\d+)"
                                                                               options:0
                                                                                 error:&error];
        if (!regex) {
            NSLog(@"error creating forumid regex: %@", error);
        }
        NSString *href = [forum objectForKey:@"href"];
        NSTextCheckingResult *match = [regex firstMatchInString:href options:0 range:NSMakeRange(0, [href length])];
        if (match) {
            forumID = [href substringWithRange:[match rangeAtIndex:1]];
        }
    }
    
    NSMutableArray *threads = [NSMutableArray new];
    for (NSString *oneThread in PerformRawHTMLXPathQuery(htmlData, @"//tr[" HAS_CLASS(thread) "]")) {
        NSData *dataForOneThread = [oneThread dataUsingEncoding:NSUTF8StringEncoding];
        ThreadParsedInfo *info = [[self alloc] initWithHTMLData:dataForOneThread];
        info.forumID = forumID;
        [threads addObject:info];
    }
    return threads;
}

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    
    TFHppleElement *row = [doc searchForSingle:@"//tr[" HAS_CLASS(thread) "]"];
    self.threadID = [[row objectForKey:@"id"] substringFromIndex:6];
    
    TFHppleElement *title = [doc searchForSingle:@"//a[" HAS_CLASS(thread_title) "]"];
    self.title = [title content];
    
    TFHppleElement *sticky = [doc searchForSingle:@"//td[" HAS_CLASS(title_sticky) "]"];
    self.sticky = !!sticky;
    
    TFHppleElement *icon = [doc searchForSingle:@"//td[" HAS_CLASS(icon) "]/img"];
    if (!icon) {
        // Film Dump rating.
        icon = [doc searchForSingle:@"//td[" HAS_CLASS(rating) "]/img[contains(@src, '/rate/reviews')]"];
    }
    if (icon) {
        self.threadIconImageURL = [NSURL URLWithString:[icon objectForKey:@"src"]];
    }
    
    TFHppleElement *icon2 = [doc searchForSingle:@"//td[" HAS_CLASS(icon2) "]/img"];
    if (icon2) {
        self.threadIconImageURL2 = [NSURL URLWithString:[icon2 objectForKey:@"src"]];
    }
    
    TFHppleElement *author = [doc searchForSingle:@"//td[" HAS_CLASS(author) "]/a"];
    self.authorName = [author content];
    
    TFHppleElement *seen = [doc searchForSingle:@"//tr[" HAS_CLASS(seen) "]"];
    self.seen = !!seen;
    
    TFHppleElement *locked = [doc searchForSingle:@"//tr[" HAS_CLASS(closed) "]"];
    self.isLocked = !!locked;
    
    TFHppleElement *star = [doc searchForSingle:@"//td[" HAS_CLASS(star) "]//img[contains(@src, 'star')]"];
    NSURL *starURL = [NSURL URLWithString:[star objectForKey:@"src"]];
    if ([[starURL lastPathComponent] hasSuffix:@"star0.gif"]) {
        self.starCategory = AwfulStarCategoryBlue;
    } else if ([[starURL lastPathComponent] hasSuffix:@"star1.gif"]) {
        self.starCategory = AwfulStarCategoryRed;
    } else if ([[starURL lastPathComponent] hasSuffix:@"star2.gif"]) {
        self.starCategory = AwfulStarCategoryYellow;
    } else {
        self.starCategory = AwfulStarCategoryNone;
    }
    
    self.totalUnreadPosts = -1;
    TFHppleElement *unread = [doc searchForSingle:@"//a[" HAS_CLASS(count) "]/b"];
    if (unread) {
        self.totalUnreadPosts = [[unread content] intValue];
    } else {
        if ([doc searchForSingle:@"//a[" HAS_CLASS(x) "]"]) {
            self.totalUnreadPosts = 0;
        }
    }
    
    TFHppleElement *total = [doc searchForSingle:@"//td[" HAS_CLASS(replies) "]/a"];
    if (!total) {
        total = [doc searchForSingle:@"//td[" HAS_CLASS(replies) "]"];
    }
    self.totalReplies = [[total content] intValue];
    
    TFHppleElement *rating = [doc searchForSingle:@"//td[" HAS_CLASS(rating) "]/img"];
    if (rating) {
        NSScanner *numberScanner = [NSScanner scannerWithString:[rating objectForKey:@"title"]];
        NSCharacterSet *notNumbers = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
        [numberScanner setCharactersToBeSkipped:notNumbers];
        NSInteger numberOfVotes;
        BOOL ok = [numberScanner scanInteger:&numberOfVotes];
        if (ok) {
            self.threadVotes = numberOfVotes;
        }
        NSDecimal average;
        ok = [numberScanner scanDecimal:&average];
        if (ok) {
            self.threadRating = [NSDecimalNumber decimalNumberWithDecimal:average];
        }
    }
    
    TFHppleElement *date = [doc searchForSingle:@"//td[" HAS_CLASS(lastpost) "]//div[" HAS_CLASS(date) "]"];
    TFHppleElement *lastAuthor = [doc searchForSingle:@"//td[" HAS_CLASS(lastpost) "]//a[" HAS_CLASS(author) "]"];
    self.lastPostAuthorName = [lastAuthor content];
    if (date) {
        static NSDateFormatter *df = nil;
        if (df == nil) {
            df = [[NSDateFormatter alloc] init];
            [df setTimeZone:[NSTimeZone localTimeZone]];
            [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        }
        static NSString *formats[] = {
            @"h:mm a MMM d, yyyy",
            @"HH:mm MMM d, yyyy",
        };
        for (size_t i = 0; i < sizeof(formats) / sizeof(formats[0]); i++) {
            [df setDateFormat:formats[i]];
            NSDate *parsedDate = [df dateFromString:[date content]];
            if (parsedDate) {
                self.lastPostDate = parsedDate;
                break;
            }
        }
    }
}

@end
