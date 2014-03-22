//  AwfulProfileScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileScraper.h"
#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import <HTMLReader/HTMLTextNode.h>

@interface AwfulProfileScraper ()

@property (strong, nonatomic) AwfulAuthorScraper *authorScraper;
@property (strong, nonatomic) AwfulCompoundDateParser *postDateParser;

@end

@implementation AwfulProfileScraper

- (AwfulAuthorScraper *)authorScraper
{
    if (!_authorScraper) _authorScraper = [AwfulAuthorScraper new];
    return _authorScraper;
}

- (AwfulCompoundDateParser *)postDateParser
{
    if (!_postDateParser) _postDateParser = [AwfulCompoundDateParser postDateParser];
    return _postDateParser;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    AwfulUser *user = [self.authorScraper scrapeAuthorFromNode:document
                                      intoManagedObjectContext:managedObjectContext];
    if (!user) {
        if (error) {
            *error = [NSError errorWithDomain:AwfulErrorDomain
                                         code:AwfulErrorCodes.parseError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Failed parsing user profile; could not find either username or user ID" }];
        }
        return nil;
    }
    HTMLElement *infoParagraph = [document awful_firstNodeMatchingCachedSelector:@"td.info p:first-of-type"];
    if (infoParagraph) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:infoParagraph.innerHTML];
        [scanner scanUpToString:@"claims to be a " intoString:nil];
        [scanner scanString:@"claims to be a " intoString:nil];
        NSString *gender;
        BOOL ok = [scanner scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&gender];
        if (ok) {
            user.gender = gender;
        }
    }
    HTMLElement *aboutParagraph = [document awful_firstNodeMatchingCachedSelector:@"td.info p:nth-of-type(2)"];
    if (aboutParagraph) {
        user.aboutMe = aboutParagraph.innerHTML;
    }
    HTMLElement *messageLink = [document awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.pm + dd a"];
    user.canReceivePrivateMessages = !!messageLink;
    HTMLElement *ICQDefinition = [document awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.icq + dd"];
    if (ICQDefinition) {
        HTMLTextNode *ICQText = ICQDefinition.children.firstObject;
        if (ICQDefinition.numberOfChildren == 1 && [ICQText isKindOfClass:[HTMLTextNode class]]) {
            user.icqName = ICQText.data;
        } else {
            user.icqName = nil;
        }
    }
    HTMLElement *AIMDefinition = [document awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.aim + dd"];
    if (AIMDefinition) {
        HTMLTextNode *AIMText = AIMDefinition.children.firstObject;
        if (AIMDefinition.numberOfChildren == 1 && [AIMText isKindOfClass:[HTMLTextNode class]]) {
            user.aimName = AIMText.data;
        } else {
            user.aimName = nil;
        }
    }
    HTMLElement *yahooDefinition = [document awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.yahoo + dd"];
    if (yahooDefinition) {
        HTMLTextNode *yahooText = yahooDefinition.children.firstObject;
        if (yahooDefinition.numberOfChildren == 1 && [yahooText isKindOfClass:[HTMLTextNode class]]) {
            user.yahooName = yahooText.data;
        } else {
            user.yahooName = nil;
        }
    }
    HTMLElement *homepageDefinition = [document awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.homepage + dd"];
    if (homepageDefinition) {
        HTMLTextNode *homepageText = homepageDefinition.children.firstObject;
        if (homepageDefinition.numberOfChildren == 1 && [homepageText isKindOfClass:[HTMLTextNode class]]) {
            user.homepageURL = [NSURL URLWithString:homepageText.data relativeToURL:documentURL];
        } else {
            user.homepageURL = nil;
        }
    }
    HTMLElement *userPictureImage = [document awful_firstNodeMatchingCachedSelector:@"div.userpic img"];
    if (userPictureImage) {
        user.profilePictureURL = [NSURL URLWithString:userPictureImage[@"src"] relativeToURL:documentURL];
    }
    HTMLElement *additionalList = [document awful_firstNodeMatchingCachedSelector:@"dl.additional"];
    HTMLElement *postCountDefinition = [additionalList awful_firstNodeMatchingCachedSelector:@"dd:nth-of-type(2)"];
    HTMLTextNode *postCountText = postCountDefinition.children.firstObject;
    if ([postCountText isKindOfClass:[HTMLTextNode class]]) {
        NSInteger postCount;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postCountText.data];
        BOOL ok = [scanner scanInteger:&postCount];
        if (ok) {
            user.postCount = (int32_t)postCount;
        }
    }
    HTMLElement *postRateDefinition = [additionalList awful_firstNodeMatchingCachedSelector:@"dd:nth-of-type(3)"];
    HTMLTextNode *postRateText = postRateDefinition.children.firstObject;
    if ([postRateText isKindOfClass:[HTMLTextNode class]]) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postRateText.data];
        BOOL ok = [scanner scanFloat:nil];
        if (ok) {
            user.postRate = [scanner.string substringToIndex:scanner.scanLocation];
        }
    }
    HTMLElement *lastPostDefinition = [additionalList awful_firstNodeMatchingCachedSelector:@"dd:nth-of-type(4)"];
    HTMLTextNode *lastPostText = lastPostDefinition.children.firstObject;
    if ([lastPostText isKindOfClass:[HTMLTextNode class]]) {
        NSDate *lastPostDate = [self.postDateParser dateFromString:lastPostText.data];
        if (lastPostDate) {
            user.lastPost = lastPostDate;
        }
    }
    NSArray *remainingAdditionalInfo = [additionalList.children.array subarrayWithRange:NSMakeRange(4, additionalList.numberOfChildren - 4)];
    for (NSUInteger i = 0; i < remainingAdditionalInfo.count; i++) {
        HTMLElement *term = remainingAdditionalInfo[i];
        if (!([term isKindOfClass:[HTMLElement class]] && [term.tagName isEqualToString:@"dt"])) continue;
        HTMLTextNode *termText = term.children.firstObject;
        if (![termText isKindOfClass:[HTMLTextNode class]]) continue;
        HTMLElement *definition = remainingAdditionalInfo[++i];
        HTMLTextNode *definitionText = definition.children.firstObject;
        if (![definitionText isKindOfClass:[HTMLTextNode class]]) continue;
        if ([termText.data hasPrefix:@"Location"]) {
            user.location = definitionText.data;
        } else if ([termText.data hasPrefix:@"Interests"]) {
            user.interests = definitionText.data;
        } else if ([termText.data hasPrefix:@"Occupation"]) {
            user.occupation = definitionText.data;
        }
    }
    [managedObjectContext save:error];
    return user;
}

@end
