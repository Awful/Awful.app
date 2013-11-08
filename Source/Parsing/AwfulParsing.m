//  AwfulParsing.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulParsing.h"
#import "AwfulThread.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import "GTMNSString+HTML.h"
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


@interface UserParsedInfo ()

@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *userID;
@property (nonatomic) NSDate *regdate;
@property (nonatomic) BOOL moderator;
@property (nonatomic) BOOL administrator;
@property (nonatomic) BOOL originalPoster;
@property (copy, nonatomic) NSString *customTitleHTML;
@property (nonatomic) BOOL canReceivePrivateMessages;

@end


@implementation UserParsedInfo

- (void)parseHTMLData
{
    
}

+ (NSArray *)keysToApplyToObject
{
    return @[ @"username", @"userID", @"regdate", @"moderator", @"administrator", @"customTitleHTML",
              @"canReceivePrivateMessages" ];
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

- (BOOL)isEqual:(BanParsedInfo *)other
{
    return ([other isKindOfClass:[BanParsedInfo class]] &&
            self.banType == other.banType &&
            [self.banDate isEqualToDate:other.banDate] &&
            [self.bannedUserID isEqualToString:other.bannedUserID]);
}

- (NSUInteger)hash
{
    return self.banDate.hash ^ self.bannedUserID.hash;
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
@property (nonatomic) NSURL *threadTagURL;
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
    self.from.customTitleHTML = [customTitle componentsJoinedByString:@""];
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
    return @[ @"messageID", @"subject", @"threadTagURL", @"seen", @"replied", @"forwarded",
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
        info.threadTagURL = [NSURL URLWithString:[tag objectForKey:@"src"]];
        
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
