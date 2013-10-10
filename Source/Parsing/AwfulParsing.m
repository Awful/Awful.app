//  AwfulParsing.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulParsing.h"
#import "AwfulThread.h"
#import "GTMNSString+HTML.h"
#import "NSURL+QueryDictionary.h"
#import "TFHpple.h"
#import "XPathQuery.h"


// XPath boilerplate to handle HTML class attribute.
//
//   NSString *xpath = @"//div[" HAS_CLASS(breadcrumbs) "]";
#define HAS_CLASS(name) "contains(concat(' ', normalize-space(@class), ' '), ' " #name " ')"


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

- (void)applyToObject:(id)object
{
    NSDictionary *values = [self dictionaryWithValuesForKeys:[[self class] keysToApplyToObject]];
    for (NSString *key in values) {
        id value = values[key];
        if (![value isEqual:[NSNull null]]) {
            [object setValue:value forKey:key];
        }
    }
}

+ (NSArray *)keysToApplyToObject
{
    return @[];
}

@end


@interface ProfileParsedInfo ()

@property (copy, nonatomic) NSString *username;
@property (nonatomic) NSDate *regdate;
@property (copy, nonatomic) NSString *customTitleHTML;
@property (copy, nonatomic) NSString *aboutMe;
@property (copy, nonatomic) NSString *aimName;
@property (copy, nonatomic) NSString *gender;
@property (nonatomic) NSURL *homepage;
@property (copy, nonatomic) NSString *icqName;
@property (copy, nonatomic) NSString *interests;
@property (nonatomic) NSDate *lastPost;
@property (copy, nonatomic) NSString *location;
@property (copy, nonatomic) NSString *occupation;
@property (nonatomic) NSInteger postCount;
@property (copy, nonatomic) NSString *postRate;
@property (nonatomic) NSURL *profilePicture;
@property (copy, nonatomic) NSString *yahooName;
@property (nonatomic) BOOL hasPlatinum;

@end


static NSDate * RegdateFromString(NSString *s)
{
    static NSDateFormatter *df = nil;
    if (!df) {
        df = [NSDateFormatter new];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [df setDateFormat:@"MMM d, yyyy"];
    }
    [df setTimeZone:[NSTimeZone localTimeZone]];
    return [df dateFromString:s];
}


static NSDate * PostDateFromString(NSString *s)
{
    static NSDateFormatter *df = nil;
    static NSArray *formats = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        
        formats = @[
            @"h:mm a MMM d, yyyy",
            @"MMM d, yyyy h:mm a",
            @"HH:mm MMM d, yyyy",
            @"MMM d, yyyy HH:mm",
            @"MM/dd/yy hh:mma"
        ];
    });
    
    [df setTimeZone:[NSTimeZone localTimeZone]];
    
    for (NSString *format in formats) {
        [df setDateFormat:format];
        NSDate *parsedDate = [df dateFromString:s];
        if (parsedDate) return parsedDate;
    }
    return nil;
}

NSString * UserIDFromURLString(NSString *s)
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"userid=(\\d+)"
                                                                           options:0
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:s
                                                    options:0
                                                      range:NSMakeRange(0, [s length])];
    if (match) return [s substringWithRange:[match rangeAtIndex:1]];
    return nil;
}

static NSString * FixSAAndlibxmlHTMLSerialization(NSString *html)
{
    if (!html) return html;
    
    // Carriage returns sneak into posts (maybe from Windows users?) and get converted into &#13;
    // by the super-smart Forums non-Windows-1252 character conversion. This adds uncollapsible
    // whitespace to the start of lines.
    html = [html stringByReplacingOccurrencesOfString:@"&#13;" withString:@""];
    
    // libxml collapses e.g. '<b></b>' into '<b/>'. WebKit then sees '<b/>', parses it as '<b>',
    // and the the rest of the document turns bold.
    NSError *error;
    NSString *pattern = @"<(b|code|em|i|q|s|small|strong|sub|sup|u)\\/>";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error compiling self-closing HTML tag regex: %@", error);
    }
    return [regex stringByReplacingMatchesInString:html options:0
                                             range:NSMakeRange(0, [html length])
                                      withTemplate:@"<$1></$1>"];
}


@implementation ProfileParsedInfo

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    
    TFHppleElement *editProfileNode = [doc searchForSingle:@"//th[starts-with(., 'Edit Profile')]"];
    if (editProfileNode) {
        [self parseHTMLDataFromEditProfilePage:doc];
    } else {
        [self parseHTMLDataFromViewProfilePage:doc];
    }
}

- (void)parseHTMLDataFromEditProfilePage:(TFHpple *)doc
{
    NSString *usernameNode = [[doc searchForSingle:
                               @"//th[starts-with(., 'Edit Profile')]/text()[1]"] content];
    if (usernameNode) {
        NSString *namePattern = @"Edit Profile - (.*)\\s$";
        NSError *error;
        NSRegularExpression *nameRegex = [NSRegularExpression regularExpressionWithPattern:namePattern
                                                                                   options:0
                                                                                     error:&error];
        if (!nameRegex) {
            NSLog(@"error creating username regex: %@", error);
        }
        NSRange allName = NSMakeRange(0, [usernameNode length]);
        NSTextCheckingResult *nameMatch = [nameRegex firstMatchInString:usernameNode
                                                                options:0
                                                                  range:allName];
        if ([nameMatch rangeAtIndex:1].location != NSNotFound) {
            self.username = [usernameNode substringWithRange:[nameMatch rangeAtIndex:1]];
        }
    }
    
    TFHppleElement *infoLink = [doc searchForSingle:@"//a[contains(@href, 'userid')]"];
    NSURL *infoURL = [NSURL URLWithString:[infoLink objectForKey:@"href"]];
    self.userID = [infoURL queryDictionary][@"userid"];
}

- (void)parseHTMLDataFromViewProfilePage:(TFHpple *)doc
{
    self.username = [[doc searchForSingle:@"//dt[" HAS_CLASS(author) "]"] content];
    self.userID = [[doc searchForSingle:@"//input[@name = 'userid']"] objectForKey:@"value"];
    TFHppleElement *regdate = [doc searchForSingle:@"//dd[" HAS_CLASS(registered) "]"];
    if (regdate) self.regdate = RegdateFromString([regdate content]);
    NSArray *titleNodes = [doc rawSearch:@"//dd[" HAS_CLASS(title) "]/node()"];
    self.customTitleHTML = [titleNodes componentsJoinedByString:@""];
    self.aboutMe = [[doc searchForSingle:@"//td[" HAS_CLASS(info) "]/p[2]"] content];
    NSString *imFormat = @"//dl[" HAS_CLASS(contacts) "]/dt[" HAS_CLASS(%@) "]/following-sibling::dd[not(span)]";
    for (NSString *im in @[ @"aim", @"icq", @"yahoo" ]) {
        TFHppleElement *imElement = [doc searchForSingle:[NSString stringWithFormat:imFormat, im]];
        if (imElement) {
            [self setValue:[imElement content] forKey:[NSString stringWithFormat:@"%@Name", im]];
        }
    }
    TFHppleElement *postCount = [doc searchForSingle:@"//dl[" HAS_CLASS(additional) "]/dt[contains(text(), 'Post Count')]/following-sibling::dd"];
    if (postCount && [[postCount content] integerValue]) {
        self.postCount = [[postCount content] integerValue];
    }
    TFHppleElement *postRate = [doc searchForSingle:@"//dl[" HAS_CLASS(additional) "]/dt[contains(text(), 'Post Rate')]/following-sibling::dd"];
    if (postRate) {
        NSString *content = [postRate content];
        NSScanner *scanner = [NSScanner scannerWithString:content];
        if ([scanner scanFloat:nil]) {
            self.postRate = [content substringToIndex:scanner.scanLocation];
        }
    }
    TFHppleElement *about = [doc searchForSingle:@"//td[" HAS_CLASS(info) "]/p[1]"];
    if (about) {
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"claims to be a ([a-z]+)"
                                      options:0
                                      error:&error];
        if (!regex) NSLog(@"error parsing profile gender regex: %@", error);
        NSTextCheckingResult *result = [regex firstMatchInString:[about content]
                                                         options:0
                                                           range:NSMakeRange(0, [[about content] length])];
        self.gender = [[about content] substringWithRange:[result rangeAtIndex:1]];
    }
    TFHppleElement *picture = [doc searchForSingle:@"//div[" HAS_CLASS(userpic) "]//img"];
    if (picture) self.profilePicture = [NSURL URLWithString:[picture objectForKey:@"src"]];
    TFHppleElement *location = [doc searchForSingle:@"//dl[" HAS_CLASS(additional) "]/dt[contains(text(), 'Location')]/following-sibling::dd"];
    self.location = [location content];
    TFHppleElement *interests = [doc searchForSingle:@"//dl[" HAS_CLASS(additional) "]/dt[contains(text(), 'Interests')]/following-sibling::dd"];
    self.interests = [interests content];
    TFHppleElement *occupation = [doc searchForSingle:@"//dl[" HAS_CLASS(additional) "]/dt[contains(text(), 'Occupation')]/following-sibling::dd"];
    self.occupation = [occupation content];
    TFHppleElement *lastPost = [doc searchForSingle:@"//dl[" HAS_CLASS(additional) "]/dt[contains(text(), 'Last Post')]/following-sibling::dd"];
    if (lastPost) self.lastPost = PostDateFromString([lastPost content]);
    self.hasPlatinum = !![doc searchForSingle:@"//dl[" HAS_CLASS(contacts) "]/dt[" HAS_CLASS(pm) "]/following-sibling::dd//a"];
}

+ (NSArray *)keysToApplyToObject
{
    return @[
        @"userID", @"username", @"regdate", @"customTitleHTML", @"aboutMe", @"aimName", @"gender",
        @"icqName", @"interests", @"lastPost", @"location", @"occupation", @"postCount",
        @"yahooName", @"postRate"
    ];
}

+ (NSArray *)keysToNullifyIfNull
{
    return @[
        @"customTitleHTML", @"aboutMe", @"aimName", @"gender", @"icqName", @"interests", @"location",
        @"occupation", @"yahooName", @"profilePicture",
    ];
}

- (void)applyToObject:(id)object
{
    [super applyToObject:object];
    for (NSString *key in [[self class] keysToNullifyIfNull]) {
        if ([[self valueForKey:key] isEqual:[NSNull null]]) {
            [object setValue:[NSNull null] forKey:key];
        }
    }
}

@end


@interface ReplyFormParsedInfo ()

@property (copy, nonatomic) NSString *formkey;
@property (copy, nonatomic) NSString *formCookie;
@property (copy, nonatomic) NSString *bookmark;
@property (copy, nonatomic) NSString *text;

@end


@implementation ReplyFormParsedInfo

- (void)parseHTMLData
{
    TFHpple *document = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    TFHppleElement *formkey = [document searchForSingle:@"//input[@name='formkey']"];
    self.formkey = [formkey objectForKey:@"value"];
    TFHppleElement *formCookie = [document searchForSingle:@"//input[@name='form_cookie']"];
    self.formCookie = [formCookie objectForKey:@"value"];
    TFHppleElement *bookmark = [document searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
    if (bookmark) {
        self.bookmark = [bookmark objectForKey:@"value"];
    }
    NSString *withEntities = [[document searchForSingle:@"//textarea[@name = 'message']"] content];
    if (withEntities) self.text = DeEntitify(withEntities);
}

static NSString * DeEntitify(NSString *withEntities)
{
    if ([withEntities length] == 0) return withEntities;
    NSMutableString *noEntities = [withEntities mutableCopy];
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"&#(\\d+);"
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error creating regex in DeEntitify: %@", error);
        return nil;
    }
    __block NSInteger offset = 0;
    [regex enumerateMatchesInString:withEntities
                            options:0
                              range:NSMakeRange(0, [withEntities length])
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags _, BOOL *__)
    {
        if ([result rangeAtIndex:1].location == NSNotFound) {
            return;
        }
        NSString *entityValue = [withEntities substringWithRange:[result rangeAtIndex:1]];
        NSNumberFormatter *formatter = [NSNumberFormatter new];
        [formatter setNumberStyle:NSNumberFormatterNoStyle];
        uint32_t codepoint = [[formatter numberFromString:entityValue] unsignedIntValue];
        NSString *character = [[NSString alloc] initWithBytes:&codepoint
                                                       length:sizeof(codepoint)
                                                     encoding:NSUTF32LittleEndianStringEncoding];
        NSRange replacementRange = [result range];
        replacementRange.location += offset;
        [noEntities replaceCharactersInRange:replacementRange withString:character];
        offset += [character length] - [result range].length;
    }];
    return noEntities;
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


@interface UserParsedInfo ()

@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *userID;
@property (nonatomic) NSDate *regdate;
@property (nonatomic) BOOL moderator;
@property (nonatomic) BOOL administrator;
@property (nonatomic) BOOL originalPoster;
@property (copy, nonatomic) NSString *customTitle;
@property (nonatomic) BOOL canReceivePrivateMessages;

@end


@implementation UserParsedInfo

- (void)parseHTMLData
{
    
}

+ (NSArray *)keysToApplyToObject
{
    return @[ @"username", @"userID", @"regdate", @"moderator", @"administrator", @"customTitle",
              @"canReceivePrivateMessages" ];
}

@end


@interface ThreadParsedInfo ()

@property (copy, nonatomic) NSString *forumID;
@property (copy, nonatomic) NSString *threadID;
@property (copy, nonatomic) NSString *title;
@property (nonatomic) BOOL sticky;
@property (nonatomic) NSURL *threadTagURL;
@property (nonatomic) NSURL *secondaryThreadTagURL;
@property (nonatomic) UserParsedInfo *author;
@property (nonatomic) BOOL seen;
@property (nonatomic) BOOL closed;
@property (nonatomic) NSInteger starCategory;
@property (nonatomic) NSInteger seenPosts;
@property (nonatomic) NSInteger totalReplies;
@property (nonatomic) NSInteger threadVotes;
@property (nonatomic) NSDecimalNumber *threadRating;
@property (copy, nonatomic) NSString *lastPostAuthorName;
@property (nonatomic) NSDate *lastPostDate;

@end


@implementation ThreadParsedInfo

- (BOOL)bookmarked
{
    return self.starCategory != AwfulStarCategoryNone;
}

+ (NSArray *)threadsWithHTMLData:(NSData *)htmlData
{
    // The breadcrumbs tell us what forum we're in!
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:htmlData];
    NSString *forumID;
    TFHppleElement *forum = [doc searchForSingle:@"(//div[" HAS_CLASS(breadcrumbs) "]//"
                             "a[contains(@href, 'forumid')])[last()]"];
    NSString *href = [forum objectForKey:@"href"];
    if (href) {
        NSError *error;
        NSString *pattern = @"forumid=(\\d+)";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:0
                                                                                 error:&error];
        if (!regex) {
            NSLog(@"error creating forumid regex: %@", error);
        }
        NSTextCheckingResult *match = [regex firstMatchInString:href options:0 range:NSMakeRange(0, [href length])];
        if (match) {
            forumID = [href substringWithRange:[match rangeAtIndex:1]];
        }
    }
    
    NSMutableArray *threads = [NSMutableArray new];
    NSArray *rawThreads = PerformRawHTMLXPathQuery(htmlData, @"//tr[" HAS_CLASS(thread) "]");
    for (NSString *oneThread in rawThreads) {
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
    
    TFHppleElement *isSticky = [doc searchForSingle:@"//td[" HAS_CLASS(title_sticky) "]"];
    self.sticky = !!isSticky;
    
    TFHppleElement *icon = [doc searchForSingle:@"//td[" HAS_CLASS(icon) "]//img"];
    if (!icon) {
        // Film Dump rating.
        icon = [doc searchForSingle:
                @"//td[" HAS_CLASS(rating) "]/img[contains(@src, '/rate/reviews')]"];
    }
    if (icon) {
        self.threadTagURL = [NSURL URLWithString:[icon objectForKey:@"src"]];
    }
    
    TFHppleElement *icon2 = [doc searchForSingle:@"//td[" HAS_CLASS(icon2) "]/img"];
    if (icon2) {
        self.secondaryThreadTagURL = [NSURL URLWithString:[icon2 objectForKey:@"src"]];
    }
    
    self.author = [UserParsedInfo new];
    TFHppleElement *author = [doc searchForSingle:@"//td[" HAS_CLASS(author) "]/a"];
    if (author) self.author.username = [[author content] gtm_stringByUnescapingFromHTML];
    NSString *profileLink = [author objectForKey:@"href"];
    if (profileLink) {
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"userid=(\\d+)"
                                                                               options:0
                                                                                 error:&error];
        if (!regex) {
            NSLog(@"error creating userid regex: %@", error);
        }
        NSTextCheckingResult *match = [regex firstMatchInString:profileLink
                                                        options:0
                                                          range:NSMakeRange(0, [profileLink length])];
        if (match) self.author.userID = [profileLink substringWithRange:[match rangeAtIndex:1]];
    }
    
    TFHppleElement *seen = [doc searchForSingle:@"//div[" HAS_CLASS(lastseen) "]"];
    self.seen = !!seen;
    
    TFHppleElement *closed = [doc searchForSingle:@"//tr[" HAS_CLASS(closed) "]"];
    self.closed = !!closed;
    
    TFHppleElement *star = [doc searchForSingle:@"//td[" HAS_CLASS(star) "]"];
    NSCharacterSet *white = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSArray *classes = [[star objectForKey:@"class"] componentsSeparatedByCharactersInSet:white];
    if ([classes containsObject:@"bm0"]) {
        self.starCategory = AwfulStarCategoryOrange;
    } else if ([classes containsObject:@"bm1"]) {
        self.starCategory = AwfulStarCategoryRed;
    } else if ([classes containsObject:@"bm2"]) {
        self.starCategory = AwfulStarCategoryYellow;
    } else {
        self.starCategory = AwfulStarCategoryNone;
    }
    
    TFHppleElement *total = [doc searchForSingle:@"//td[" HAS_CLASS(replies) "]/a"];
    if (!total) {
        total = [doc searchForSingle:@"//td[" HAS_CLASS(replies) "]"];
    }
    self.totalReplies = [[total content] intValue];
    
    TFHppleElement *unread = [doc searchForSingle:@"//a[" HAS_CLASS(count) "]/b"];
    if (unread) {
        self.seenPosts = self.totalReplies + 1 - [[unread content] intValue];
    } else {
        if ([doc searchForSingle:@"//a[" HAS_CLASS(x) "]"]) {
            self.seenPosts = self.totalReplies + 1;
        }
    }
    
    TFHppleElement *rating = [doc searchForSingle:@"//td[" HAS_CLASS(rating) "]/img"];
    if (rating) {
        NSScanner *numberScanner = [NSScanner scannerWithString:[rating objectForKey:@"title"]];
        NSCharacterSet *notNumbers = [[NSCharacterSet characterSetWithCharactersInString:
                                       @"0123456789."] invertedSet];
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
    
    TFHppleElement *date = [doc searchForSingle:
                            @"//td[" HAS_CLASS(lastpost) "]//div[" HAS_CLASS(date) "]"];
    TFHppleElement *lastAuthor = [doc searchForSingle:
                                  @"//td[" HAS_CLASS(lastpost) "]//a[" HAS_CLASS(author) "]"];
    self.lastPostAuthorName = [lastAuthor content];
    if (date) self.lastPostDate = PostDateFromString([date content]);
}

+ (NSArray *)keysToApplyToObject
{
    return @[
        @"threadID", @"title", @"threadTagURL", @"secondaryThreadTagURL", @"sticky",
        @"closed", @"starCategory", @"totalReplies", @"seenPosts", @"threadVotes",
        @"threadRating", @"lastPostAuthorName", @"lastPostDate", @"bookmarked"
    ];
}

@end


@interface PostParsedInfo ()

@property (copy, nonatomic) NSString *postID;
@property (copy, nonatomic) NSString *threadIndex;
@property (nonatomic) NSDate *postDate;
@property (nonatomic) UserParsedInfo *author;
@property (getter=isEditable, nonatomic) BOOL editable;
@property (nonatomic) BOOL beenSeen;
@property (copy, nonatomic) NSString *innerHTML;

@end


@implementation PostParsedInfo

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    
    TFHppleElement *table = [doc searchForSingle:@"//table[" HAS_CLASS(post) "]"];
    self.postID = [[table objectForKey:@"id"] substringFromIndex:4];
    self.threadIndex = [table objectForKey:@"data-idx"];
    
    NSString *postdate = [[doc searchForSingle:@"//td[" HAS_CLASS(postdate) "]"] content];
    if (postdate) {
        static NSDateFormatter *df = nil;
        if (!df) {
            df = [NSDateFormatter new];
            [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        }
        [df setTimeZone:[NSTimeZone localTimeZone]];
        static NSString *formats[] = {
            @"MMM d, yyyy h:mm a",
            @"MMM d, yyyy HH:mm"
        };
        for (size_t i = 0; i < sizeof(formats) / sizeof(formats[0]); i++) {
            [df setDateFormat:formats[i]];
            NSDate *parsedDate = [df dateFromString:postdate];
            if (parsedDate) {
                self.postDate = parsedDate;
                break;
            }
        }
    }
    
    self.author = [UserParsedInfo new];
    TFHppleElement *author = [doc searchForSingle:@"//dt[" HAS_CLASS(author) "]"];
    self.author.username = [[author content] gtm_stringByUnescapingFromHTML];
    NSCharacterSet *space = [NSCharacterSet whitespaceCharacterSet];
    NSArray *authorClasses = [[author objectForKey:@"class"]
                              componentsSeparatedByCharactersInSet:space];
    self.author.moderator = [authorClasses containsObject:@"role-mod"];
    self.author.administrator = [authorClasses containsObject:@"role-admin"];
    self.author.originalPoster = [authorClasses containsObject:@"op"];
    NSString *regdate = [[doc searchForSingle:@"//dd[" HAS_CLASS(registered) "]"] content];
    if (regdate) self.author.regdate = RegdateFromString(regdate);
    NSArray *customTitleNodes = [doc rawSearch:@"//dl[" HAS_CLASS(userinfo) "]//dd[" HAS_CLASS(title) "]//node()"];
    self.author.customTitle = [customTitleNodes componentsJoinedByString:@""];
    TFHppleElement *messageLink = [doc searchForSingle:@"//ul[" HAS_CLASS(profilelinks) "]//a[contains(@href, 'private.php')]"];
    self.author.canReceivePrivateMessages = !!messageLink;
    TFHppleElement *showPostsByUser = [doc searchForSingle:@"//a[" HAS_CLASS(user_jump) "]"];
    NSString *linkWithUserid = [showPostsByUser objectForKey:@"href"];
    if ([linkWithUserid rangeOfString:@"userid"].location == NSNotFound) {
        TFHppleElement *profileLink = [doc searchForSingle:@"//ul[" HAS_CLASS(profilelinks) "]//a"];
        linkWithUserid = [profileLink objectForKey:@"href"];
    }
    if (linkWithUserid) {
        NSScanner *scanner = [NSScanner scannerWithString:linkWithUserid];
        [scanner scanUpToString:@"userid=" intoString:NULL];
        [scanner scanString:@"userid=" intoString:NULL];
        NSInteger userID;
        BOOL ok = [scanner scanInteger:&userID];
        if (ok) {
            self.author.userID = [@(userID) stringValue];
        } else {
            NSLog(@"could not parse post author ID from %@", scanner.string);
        }
    }
    
    self.editable = !![doc searchForSingle:
                       @"//ul[" HAS_CLASS(postbuttons) "]//a[contains(@href, 'editpost')]"];
    
    self.beenSeen = !![doc searchForSingle:@"//tr[" HAS_CLASS(seen1) " or " HAS_CLASS(seen2) "]"];
    
    // FYAD and subforums store the post text in a div within postbody.
    NSString *innerHTML = [[doc rawSearch:@"//div[" HAS_CLASS(complete_shit) "]"] lastObject];
    // Everything else just uses the postbody.
    if (!innerHTML) {
        innerHTML = [[doc rawSearch:@"//td[" HAS_CLASS(postbody) "]"] lastObject];
    }
    self.innerHTML = FixSAAndlibxmlHTMLSerialization(innerHTML);
}

+ (NSArray *)keysToApplyToObject
{
    return @[ @"postID", @"innerHTML", @"postDate", @"editable" ];
}

@end


@interface PageParsedInfo ()

@property (copy, nonatomic) NSArray *posts;
@property (nonatomic) NSInteger pageNumber;
@property (nonatomic) NSInteger pagesInThread;
@property (copy, nonatomic) NSString *advertisementHTML;
@property (copy, nonatomic) NSString *forumID;
@property (copy, nonatomic) NSString *forumName;
@property (copy, nonatomic) NSString *threadID;
@property (copy, nonatomic) NSString *threadTitle;
@property (getter=isThthreadClosed, nonatomic) BOOL threadClosed;
@property (getter=isThreadBookmarked, nonatomic) BOOL threadBookmarked;

@end


@implementation PageParsedInfo

- (id)initWithHTMLData:(NSData *)htmlData
{
    _pageNumber = 1;
    _pagesInThread = 1;
    return [super initWithHTMLData:htmlData];
}

- (void)parseHTMLData
{
    NSString *broken = [[NSString alloc] initWithData:self.htmlData encoding:NSUTF8StringEncoding];
    // Sometimes we get weird pseudo-tags like '<size:8>' that wreck our day. Make them go away.
    NSString *pattern = @"<\\/?size:\\d+>";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error compiling <size:8> regex: %@", error);
    }
    NSString *fixedString = [regex stringByReplacingMatchesInString:broken options:0
                                                              range:NSMakeRange(0, [broken length])
                                                       withTemplate:@""];
    NSData *fixed = [fixedString dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:fixed];
    
    TFHppleElement *threadLink = [doc searchForSingle:@"//a[" HAS_CLASS(bclast) "]"];
    self.threadTitle = [threadLink content];
    NSURL *threadURL = [NSURL URLWithString:[threadLink objectForKey:@"href"]];
    self.threadID = [threadURL queryDictionary][@"threadid"];
    
    self.threadClosed = !![doc searchForSingle:
                           @"//a[contains(@href, 'newreply')]/img[contains(@src, 'closed')]"];
    
    TFHppleElement *forumLink = [doc searchForSingle:
                                 @"//div[" HAS_CLASS(breadcrumbs) "]//a[position() = last() - 1]"];
    self.forumName = [forumLink content];
    NSURL *forumURL = [NSURL URLWithString:[forumLink objectForKey:@"href"]];
    self.forumID = [forumURL queryDictionary][@"forumid"];
    
    if ([doc searchForSingle:@"//div[" HAS_CLASS(pages) "]/select"]) {
        TFHppleElement *lastPage = [doc searchForSingle:@"//div[" HAS_CLASS(pages) "]/select/option[position() = last()]"];
        NSInteger numberOfPages = [[lastPage content] integerValue];
        if (numberOfPages > 0) self.pagesInThread = numberOfPages;
        TFHppleElement *currentPage = [doc searchForSingle:
                                       @"//div[" HAS_CLASS(pages) "]/select/option[@selected]"];
        NSInteger pageNumber = [[currentPage content] integerValue];
        if (pageNumber > 0) self.pageNumber = pageNumber;
    } else {
        NSString *pages = [[doc searchForSingle:@"//div[" HAS_CLASS(pages) "]/text()"] content];
        if (pages) {
            NSString *pattern = @"[(](\\d+)[)]";
            NSError *error;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                   options:0
                                                                                     error:&error];
            if (!regex) NSLog(@"error compiling number of pages regex: %@", error);
            NSTextCheckingResult *match = [regex firstMatchInString:pages
                                                            options:0
                                                              range:NSMakeRange(0, [pages length])];
            if ([match rangeAtIndex:1].location != NSNotFound) {
                NSInteger pageCount = [[pages substringWithRange:[match rangeAtIndex:1]] integerValue];
                if (pageCount > 0) self.pagesInThread = pageCount;
            }
        }
        TFHppleElement *currentPage = [doc searchForSingle:@"//div[" HAS_CLASS(pages) "]//span[" HAS_CLASS(curpage) "]"];
        NSInteger pageNumber = [[currentPage content] integerValue];
        if (pageNumber > 0) self.pageNumber = pageNumber;
    }
    
    NSArray *ads = [doc rawSearch:@"(//div[@id = 'ad_banner_user']/a)[1]"];
    if ([ads count] > 0) self.advertisementHTML = ads[0];
    
    TFHppleElement *mark = [doc searchForSingle:@"//img[" HAS_CLASS(thread_bookmark) " and " HAS_CLASS(unbookmark) "]"];
    self.threadBookmarked = !!mark;
    
    NSMutableArray *posts = [NSMutableArray new];
    NSString *path = @"//table[" HAS_CLASS(post) "]";
    NSArray *listOfRawPosts = PerformRawHTMLXPathQuery(fixed, path);
    for (NSString *rawPost in listOfRawPosts) {
        NSData *postData = [rawPost dataUsingEncoding:NSUTF8StringEncoding];
        [posts addObject:[[PostParsedInfo alloc] initWithHTMLData:postData]];
    }
    self.posts = posts;
}

@end


@interface SuccessfulReplyInfo ()

@property (copy, nonatomic) NSString *postID;
@property (nonatomic) BOOL lastPage;

@end


@implementation SuccessfulReplyInfo

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    TFHppleElement *a = [doc searchForSingle:@"//a[contains(@href, 'goto=post')]"];
    if (a) {
        NSURL *sa = [NSURL URLWithString:@"http://forums.somethingawful.com"];
        NSURL *url = [NSURL URLWithString:[a objectForKey:@"href"] relativeToURL:sa];
        self.postID = [url queryDictionary][@"postid"];
    } else {
        a = [doc searchForSingle:@"//a[contains(@href, 'goto=lastpost')]"];
        if (a) self.lastPage = YES;
    }
}

@end


@interface BanParsedInfo ()

@property (nonatomic) AwfulBanType banType;
@property (copy, nonatomic) NSString *postID;
@property (nonatomic) NSDate *banDate;
@property (copy, nonatomic) NSString *bannedUserID;
@property (copy, nonatomic) NSString *bannedUserName;
@property (copy, nonatomic) NSString *banReason;
@property (copy, nonatomic) NSString *requesterUserID;
@property (copy, nonatomic) NSString *requesterUserName;
@property (copy, nonatomic) NSString *approverUserID;
@property (copy, nonatomic) NSString *approverUserName;

@end



@implementation BanParsedInfo

+ (NSArray*)bansWithHTMLData:(NSData *)htmlData
{
    NSMutableArray *bans = [NSMutableArray new];
    NSArray *rows = PerformRawHTMLXPathQuery(htmlData, @"//table[" HAS_CLASS(standard) " and " HAS_CLASS(full) "]//tr[position() > 1]");
    for (NSString *row in rows) {
        NSData *rowData = [row dataUsingEncoding:NSUTF8StringEncoding];
        BanParsedInfo *info = [[self alloc] initWithHTMLData:rowData];
        [bans addObject:info];
    }
    return bans;
}

typedef NS_ENUM(NSUInteger, LepersColonyColumn) {
    LepersColonyColumnType = 0,
    LepersColonyColumnDate,
    LepersColonyColumnJerk,
    LepersColonyColumnReason,
    LepersColonyColumnRequester,
    LepersColonyColumnApprover
};

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    NSArray *tds = [doc search:@"//td"];
    if (tds.count != 6) return;
    
    TFHppleElement *b = [tds[LepersColonyColumnType] firstChildWithTagName:@"b"];
    TFHppleElement *a = [b firstChildWithTagName:@"a"];
    if (a) {
        NSURL *url = [NSURL URLWithString:a.attributes[@"href"]];
        self.postID = [url queryDictionary][@"postid"];
    }
    self.banDate = PostDateFromString([tds[LepersColonyColumnDate] content]);
    self.banType = BanTypeWithString(a ? a.content : b.content);
    
    b = [tds[LepersColonyColumnJerk] firstChildWithTagName:@"b"];
    a = [b firstChildWithTagName:@"a"];
    if (a) {
        self.bannedUserID = UserIDFromURLString(a.attributes[@"href"]);
        self.bannedUserName = a.content;
    }
    
    self.banReason = [tds[LepersColonyColumnReason] content];
    
    a = [tds[LepersColonyColumnRequester] childrenWithTagName:@"a"][0];
    self.requesterUserID = UserIDFromURLString(a.attributes[@"href"]);
    self.requesterUserName = a.content;
    
    a = [tds[LepersColonyColumnApprover] childrenWithTagName:@"a"][0];
    self.approverUserID = UserIDFromURLString(a.attributes[@"href"]);
    self.approverUserName = a.content;
}

static AwfulBanType BanTypeWithString(NSString *s)
{
    static NSDictionary *banTypes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        banTypes = @{
            @"PROBATION": @(AwfulBanTypeProbation),
            @"BAN": @(AwfulBanTypeBan),
            @"AUTOBAN": @(AwfulBanTypeAutoban),
            @"PERMABAN": @(AwfulBanTypePermaban),
        };
    });
    return [banTypes[s] integerValue];
}

@end


static BOOL PrivateMessageIconReplied(NSString *src)
{
    return [src rangeOfString:@"replied"].location != NSNotFound;
}


static BOOL PrivateMessageIconForwarded(NSString *src)
{
    return [src rangeOfString:@"forwarded"].location != NSNotFound;
}


static BOOL PrivateMessageIconSeen(NSString *src)
{
    return [src rangeOfString:@"newpm"].location == NSNotFound;
}


@interface PrivateMessageParsedInfo ()

@property (copy, nonatomic) NSString *messageID;
@property (copy, nonatomic) NSString *subject;
@property (nonatomic) NSDate *sentDate;
@property (nonatomic) NSURL *messageIconImageURL;
@property (nonatomic) UserParsedInfo *from;
@property (nonatomic) UserParsedInfo *to;
@property (nonatomic) BOOL seen;
@property (nonatomic) BOOL replied;
@property (nonatomic) BOOL forwarded;
@property (nonatomic) NSString *innerHTML;

@end


@implementation PrivateMessageParsedInfo

- (void)parseHTMLData
{
    if (!self.htmlData) return;
    self.from = [UserParsedInfo new];
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    TFHppleElement *profile = [doc searchForSingle:@"//ul[" HAS_CLASS(profilelinks) "]//a"];
    if (profile) {
        NSScanner *scanner = [NSScanner scannerWithString:[profile objectForKey:@"href"]];
        [scanner scanUpToString:@"userid=" intoString:NULL];
        [scanner scanString:@"userid=" intoString:NULL];
        NSInteger userID;
        BOOL ok = [scanner scanInteger:&userID];
        if (ok) {
            self.from.userID = [@(userID) stringValue];
        } else {
            NSLog(@"could not parse user ID from %@", scanner.string);
        }
    }
    TFHppleElement *username = [doc searchForSingle:@"//dl[" HAS_CLASS(userinfo)
                                "]//dt[" HAS_CLASS(author) "]"];
    self.from.username = [[username content] gtm_stringByUnescapingFromHTML];
    TFHppleElement *regdate = [doc searchForSingle:@"//dl[" HAS_CLASS(userinfo)
                               "]//dd[" HAS_CLASS(registered) "]"];
    self.from.regdate = RegdateFromString([regdate content]);
    NSArray *customTitle = PerformRawHTMLXPathQuery(self.htmlData, @"//dl[" HAS_CLASS(userinfo)
                                                    "]//dd[" HAS_CLASS(title) "][1]/node()");
    self.from.customTitle = [customTitle componentsJoinedByString:@""];
    TFHppleElement *roleHolder = [doc searchForSingle:@"//dl[" HAS_CLASS(userinfo) "]//dt[" HAS_CLASS(author) "]"];
    if (roleHolder) {
        NSString *classAttribute = [roleHolder objectForKey:@"class"];
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSArray *classes = [classAttribute componentsSeparatedByCharactersInSet:whitespace];
        if ([classes containsObject:@"role-admin"]) {
            self.from.administrator = YES;
        }
        if ([classes containsObject:@"role-mod"]) {
            self.from.moderator = YES;
        }
    }
    TFHppleElement *reply = [doc searchForSingle:@"//div[" HAS_CLASS(buttons) "]//a"];
    if (reply) {
        NSScanner *scanner = [NSScanner scannerWithString:[reply objectForKey:@"href"]];
        [scanner scanUpToString:@"privatemessageid=" intoString:NULL];
        [scanner scanString:@"privatemessageid=" intoString:NULL];
        NSInteger messageID;
        BOOL ok = [scanner scanInteger:&messageID];
        if (ok) {
            self.messageID = [@(messageID) stringValue];
        } else {
            NSLog(@"could not parse message ID from %@", scanner.string);
        }
    }
    TFHppleElement *subject = [doc searchForSingle:@"//div[" HAS_CLASS(breadcrumbs)
                               "]//a[last()]/following-sibling::node()"];
    self.subject = [subject content];
    TFHppleElement *seenIcon = [doc searchForSingle:@"//td[" HAS_CLASS(postdate) "]//img"];
    if (seenIcon) {
        self.replied = PrivateMessageIconReplied([seenIcon objectForKey:@"src"]);
        self.forwarded = PrivateMessageIconForwarded([seenIcon objectForKey:@"src"]);
        self.seen = PrivateMessageIconSeen([seenIcon objectForKey:@"src"]);
    }
    TFHppleElement *sentDate = [doc searchForSingle:@"//td[" HAS_CLASS(postdate) "]/text()"];
    self.sentDate = PostDateFromString([sentDate content]);
    NSArray *postbody = PerformRawHTMLXPathQuery(self.htmlData,
                                                 @"//td[" HAS_CLASS(postbody) "][1]/node()");
    self.innerHTML = FixSAAndlibxmlHTMLSerialization([postbody componentsJoinedByString:@""]);
}

+ (NSArray *)keysToApplyToObject
{
    return @[ @"messageID", @"subject", @"messageIconImageURL", @"seen", @"replied", @"forwarded",
              @"sentDate", @"innerHTML" ];
}

@end


@interface PrivateMessageFolderParsedInfo ()

@property (copy, nonatomic) NSArray *privateMessages;

@end


@implementation PrivateMessageFolderParsedInfo

- (void)parseHTMLData
{
    NSMutableArray *messages = [NSMutableArray new];
    for (NSString *rawRow in PerformRawHTMLXPathQuery(self.htmlData, @"//tbody/tr")) {
        NSData *rowData = [rawRow dataUsingEncoding:NSUTF8StringEncoding];
        TFHpple *row = [[TFHpple alloc] initWithHTMLData:rowData];
        PrivateMessageParsedInfo *info = [PrivateMessageParsedInfo new];
        NSString *seenImageSrc = [[row searchForSingle:@"//td[1]//img"] objectForKey:@"src"];
        info.replied = PrivateMessageIconReplied(seenImageSrc);
        info.forwarded = PrivateMessageIconForwarded(seenImageSrc);
        info.seen = PrivateMessageIconSeen(seenImageSrc);
        
        TFHppleElement *tag = [row searchForSingle:@"//td[2]//img"];
        info.messageIconImageURL = [NSURL URLWithString:[tag objectForKey:@"src"]];
        
        TFHppleElement *subject = [row searchForSingle:@"//td[3]//a"];
        if (subject) {
            info.subject = subject.content;
            NSScanner *scanner = [NSScanner scannerWithString:[subject objectForKey:@"href"]];
            NSString *numberFollows = @"privatemessageid=";
            [scanner scanUpToString:numberFollows intoString:NULL];
            [scanner scanString:numberFollows intoString:NULL];
            NSInteger messageID;
            BOOL ok = [scanner scanInteger:&messageID];
            if (ok) {
                info.messageID = [@(messageID) stringValue];
            } else {
                NSLog(@"could not parse private message ID from %@", scanner.string);
            }
        }
        
        TFHppleElement *fromCell = [row searchForSingle:@"//td[4]"];
        info.from = [UserParsedInfo new];
        info.from.username = [fromCell.content gtm_stringByUnescapingFromHTML];
        
        TFHppleElement *sentDateCell = [row searchForSingle:@"//td[5]"];
        if (sentDateCell) {
            static NSDateFormatter *df = nil;
            if (!df) {
                df = [[NSDateFormatter alloc] init];
                [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
            }
            [df setTimeZone:[NSTimeZone localTimeZone]];
            NSString *dateString = [sentDateCell content];
            [df setDateFormat:@"MMM d, yyyy 'at' HH:mm"];
            NSDate *date = [df dateFromString:dateString];
            if (!date) {
                [df setDateFormat:@"MMM d, yyyy 'at' h:mm a"];
                date = [df dateFromString:dateString];
            }
            info.sentDate = date;
        }
        [messages addObject:info];
    }
    self.privateMessages = messages;
}

@end


@interface ComposePrivateMessageParsedInfo ()

@property (nonatomic) NSMutableDictionary *mutablePostIcons;
@property (nonatomic) NSMutableArray *mutablePostIconIDs;
@property (nonatomic) NSMutableDictionary *mutableSecondaryIcons;
@property (nonatomic) NSMutableArray *mutableSecondaryIconIDs;
@property (copy, nonatomic) NSString *secondaryIconKey;
@property (copy, nonatomic) NSString *selectedSecondaryIconID;
@property (copy, nonatomic) NSString *text;

@end


@implementation ComposePrivateMessageParsedInfo

- (NSDictionary *)postIcons
{
    return self.mutablePostIcons;
}

- (NSArray *)postIconIDs
{
    return self.mutablePostIconIDs;
}

- (NSDictionary *)secondaryIcons
{
    return self.mutableSecondaryIcons;
}

- (NSArray *)secondaryIconIDs
{
    return self.mutableSecondaryIconIDs;
}

- (void)parseHTMLData
{
    self.mutablePostIcons = [NSMutableDictionary new];
    self.mutablePostIconIDs = [NSMutableArray new];
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    NSArray *inputs = [doc search:@"//div[" HAS_CLASS(posticon) "]//input[1]"];
    NSArray *imgs = [doc search:@"//div[" HAS_CLASS(posticon) "]//img[1]"];
    if ([inputs count] != [imgs count]) {
        NSLog(@"could not parse available private message post icons");
        return;
    }
    for (NSUInteger i = 0; i < [inputs count]; i++) {
        NSString *iconID = [inputs[i] objectForKey:@"value"];
        NSURL *url = [NSURL URLWithString:[imgs[i] objectForKey:@"src"]];
        if (iconID && url) {
            self.mutablePostIcons[iconID] = url;
            [self.mutablePostIconIDs addObject:iconID];
        }
    }
    
    NSArray *secondaryInputs = [doc search:@"//input[@name = 'tma_ama']"];
    NSArray *secondaryImages;
    if ([secondaryInputs count] > 0) {
        secondaryImages = [doc search:@"//img[preceding-sibling::input[@name = 'tma_ama']]"];
        self.secondaryIconKey = @"tma_ama";
    } else {
        secondaryInputs = [doc search:@"//input[@name = 'samart_tag']"];
        if ([secondaryInputs count] > 0) {
            secondaryImages = [doc search:@"//img[preceding-sibling::input[@name = 'samart_tag']]"];
            self.secondaryIconKey = @"samart_tag";
        }
    }
    if ([secondaryInputs count] != [secondaryImages count]) {
        NSLog(@"could not parse available secondary post icons");
        return;
    }
    if ([secondaryInputs count] > 0) {
        self.mutableSecondaryIcons = [NSMutableDictionary new];
        self.mutableSecondaryIconIDs = [NSMutableArray new];
    }
    for (NSUInteger i = 0; i < [secondaryInputs count]; i++) {
        NSString *iconID = [secondaryInputs[i] objectForKey:@"value"];
        NSURL *url = [NSURL URLWithString:[secondaryImages[i] objectForKey:@"src"]];
        if (iconID && url) {
            self.mutableSecondaryIcons[iconID] = url;
            [self.mutableSecondaryIconIDs addObject:iconID];
            if ([secondaryInputs[i] objectForKey:@"checked"]) {
                self.selectedSecondaryIconID = iconID;
            }
        }
    }
    
    NSArray *textNodes = [doc rawSearch:@"//textarea[@name = 'message']/text()"];
    NSString *text = [textNodes componentsJoinedByString:@""];
    self.text = DeEntitify(text ?: @"");
}

@end


@interface NewThreadFormParsedInfo ()

@property (copy, nonatomic) NSString *formkey;
@property (copy, nonatomic) NSString *formCookie;
@property (copy, nonatomic) NSString *automaticallyParseURLs;
@property (copy, nonatomic) NSString *bookmarkThread;

@end

@implementation NewThreadFormParsedInfo

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    TFHppleElement *formkey = [doc searchForSingle:@"//input[@name = 'formkey']"];
    self.formkey = [formkey objectForKey:@"value"];
    TFHppleElement *formCookie = [doc searchForSingle:@"//input[@name = 'form_cookie']"];
    self.formCookie = [formCookie objectForKey:@"value"];
    TFHppleElement *parseURLs = [doc searchForSingle:
                                 @"//input[@name = 'parseurl' and @checked = 'checked']"];
    self.automaticallyParseURLs = [parseURLs objectForKey:@"value"];
    TFHppleElement *bookmarkThread = [doc searchForSingle:
                                      @"//input[@name = 'bookmark' and @checked = 'checked']"];
    self.bookmarkThread = [bookmarkThread objectForKey:@"value"];
}

@end


@interface SuccessfulNewThreadParsedInfo ()

@property (copy, nonatomic) NSString *threadID;

@end

@implementation SuccessfulNewThreadParsedInfo

- (void)parseHTMLData
{
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    TFHppleElement *threadLink = [doc searchForSingle:@"//a[contains(@href, 'showthread')]"];
    NSURL *url = [NSURL URLWithString:[threadLink objectForKey:@"href"]];
    self.threadID = url.queryDictionary[@"threadid"];
}

@end
