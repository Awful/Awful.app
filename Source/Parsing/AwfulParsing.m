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
