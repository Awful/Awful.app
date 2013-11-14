//  AwfulProfileScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileScraper.h"
#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"

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
    HTMLElementNode *infoParagraph = [document firstNodeMatchingSelector:@"td.info p:first-of-type"];
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
    HTMLElementNode *aboutParagraph = [document firstNodeMatchingSelector:@"td.info p:nth-of-type(2)"];
    if (aboutParagraph) {
        user.aboutMe = aboutParagraph.innerHTML;
    }
    HTMLElementNode *messageLink = [document firstNodeMatchingSelector:@"dl.contacts dt.pm + dd a"];
    user.canReceivePrivateMessages = !!messageLink;
    HTMLElementNode *ICQDefinition = [document firstNodeMatchingSelector:@"dl.contacts dt.icq + dd"];
    if (ICQDefinition) {
        HTMLTextNode *ICQText = ICQDefinition.childNodes.firstObject;
        if (ICQDefinition.childNodes.count == 1 && [ICQText isKindOfClass:[HTMLTextNode class]]) {
            user.icqName = ICQText.data;
        } else {
            user.icqName = nil;
        }
    }
    HTMLElementNode *AIMDefinition = [document firstNodeMatchingSelector:@"dl.contacts dt.aim + dd"];
    if (AIMDefinition) {
        HTMLTextNode *AIMText = AIMDefinition.childNodes.firstObject;
        if (AIMDefinition.childNodes.count == 1 && [AIMText isKindOfClass:[HTMLTextNode class]]) {
            user.aimName = AIMText.data;
        } else {
            user.aimName = nil;
        }
    }
    HTMLElementNode *yahooDefinition = [document firstNodeMatchingSelector:@"dl.contacts dt.yahoo + dd"];
    if (yahooDefinition) {
        HTMLTextNode *yahooText = yahooDefinition.childNodes.firstObject;
        if (yahooDefinition.childNodes.count == 1 && [yahooText isKindOfClass:[HTMLTextNode class]]) {
            user.yahooName = yahooText.data;
        } else {
            user.yahooName = nil;
        }
    }
    HTMLElementNode *homepageDefinition = [document firstNodeMatchingSelector:@"dl.contacts dt.homepage + dd"];
    if (homepageDefinition) {
        HTMLTextNode *homepageText = homepageDefinition.childNodes.firstObject;
        if (homepageDefinition.childNodes.count == 1 && [homepageText isKindOfClass:[HTMLTextNode class]]) {
            user.homepageURL = [NSURL URLWithString:homepageText.data relativeToURL:documentURL];
        } else {
            user.homepageURL = nil;
        }
    }
    HTMLElementNode *userPictureImage = [document firstNodeMatchingSelector:@"div.userpic img"];
    if (userPictureImage) {
        user.profilePictureURL = [NSURL URLWithString:userPictureImage[@"src"] relativeToURL:documentURL];
    }
    HTMLElementNode *additionalList = [document firstNodeMatchingSelector:@"dl.additional"];
    HTMLElementNode *postCountDefinition = [additionalList firstNodeMatchingSelector:@"dd:nth-of-type(2)"];
    HTMLTextNode *postCountText = postCountDefinition.childNodes.firstObject;
    if ([postCountText isKindOfClass:[HTMLTextNode class]]) {
        NSInteger postCount;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postCountText.data];
        BOOL ok = [scanner scanInteger:&postCount];
        if (ok) {
            user.postCount = postCount;
        }
    }
    HTMLElementNode *postRateDefinition = [additionalList firstNodeMatchingSelector:@"dd:nth-of-type(3)"];
    HTMLTextNode *postRateText = postRateDefinition.childNodes.firstObject;
    if ([postRateText isKindOfClass:[HTMLTextNode class]]) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postRateText.data];
        BOOL ok = [scanner scanFloat:nil];
        if (ok) {
            user.postRate = [scanner.string substringToIndex:scanner.scanLocation];
        }
    }
    HTMLElementNode *lastPostDefinition = [additionalList firstNodeMatchingSelector:@"dd:nth-of-type(4)"];
    HTMLTextNode *lastPostText = lastPostDefinition.childNodes.firstObject;
    if ([lastPostText isKindOfClass:[HTMLTextNode class]]) {
        NSDate *lastPostDate = [self.postDateParser dateFromString:lastPostText.data];
        if (lastPostDate) {
            user.lastPost = lastPostDate;
        }
    }
    NSArray *remainingAdditionalInfo = [additionalList.childNodes subarrayWithRange:NSMakeRange(4, additionalList.childNodes.count - 4)];
    for (NSUInteger i = 0; i < remainingAdditionalInfo.count; i++) {
        HTMLElementNode *term = remainingAdditionalInfo[i];
        if (!([term isKindOfClass:[HTMLElementNode class]] && [term.tagName isEqualToString:@"dt"])) continue;
        HTMLTextNode *termText = term.childNodes.firstObject;
        if (![termText isKindOfClass:[HTMLTextNode class]]) continue;
        HTMLElementNode *definition = remainingAdditionalInfo[++i];
        HTMLTextNode *definitionText = definition.childNodes.firstObject;
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
