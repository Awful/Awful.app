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

@property (strong, nonatomic) AwfulUser *user;

@end

@implementation AwfulProfileScraper

- (void)scrape
{
    AwfulAuthorScraper *authorScraper = [AwfulAuthorScraper scrapeNode:self.node intoManagedObjectContext:self.managedObjectContext];
    if (!authorScraper.author) {
        NSString *message = @"Failed parsing user profile; could not find either username or user ID";
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    self.user = authorScraper.author;
    
    HTMLElement *infoParagraph = [self.node awful_firstNodeMatchingCachedSelector:@"td.info p:first-of-type"];
    if (infoParagraph) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:infoParagraph.innerHTML];
        [scanner scanUpToString:@"claims to be a " intoString:nil];
        [scanner scanString:@"claims to be a " intoString:nil];
        NSString *gender;
        BOOL ok = [scanner scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&gender];
        if (ok) {
            self.user.gender = gender;
        }
    }
    
    HTMLElement *aboutParagraph = [self.node awful_firstNodeMatchingCachedSelector:@"td.info p:nth-of-type(2)"];
    if (aboutParagraph) {
        self.user.aboutMe = aboutParagraph.innerHTML;
    }
    
    HTMLElement *messageLink = [self.node awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.pm + dd a"];
    self.user.canReceivePrivateMessages = !!messageLink;
    
    HTMLElement *ICQDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.icq + dd"];
    if (ICQDefinition) {
        NSString *ICQText = [ICQDefinition.children.firstObject textContent];
        if (ICQDefinition.numberOfChildren == 1 && [ICQDefinition.children[0] isKindOfClass:[HTMLTextNode class]]) {
            self.user.icqName = ICQText;
        } else {
            self.user.icqName = nil;
        }
    }
    
    HTMLElement *AIMDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.aim + dd"];
    if (AIMDefinition) {
        NSString *AIMText = [AIMDefinition.children.firstObject textContent];
        if (AIMDefinition.numberOfChildren == 1 && [AIMDefinition.children[0] isKindOfClass:[HTMLTextNode class]]) {
            self.user.aimName = AIMText;
        } else {
            self.user.aimName = nil;
        }
    }
    
    HTMLElement *yahooDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.yahoo + dd"];
    if (yahooDefinition) {
        NSString *yahooText = [yahooDefinition.children.firstObject textContent];
        if (yahooDefinition.numberOfChildren == 1 && [yahooDefinition.children[0] isKindOfClass:[HTMLTextNode class]]) {
            self.user.yahooName = yahooText;
        } else {
            self.user.yahooName = nil;
        }
    }
    
    HTMLElement *homepageDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dl.contacts dt.homepage + dd"];
    if (homepageDefinition) {
        NSString *homepageText = [homepageDefinition.children.firstObject textContent];
        if (homepageText.length > 0) {
            self.user.homepageURL = [NSURL URLWithString:homepageText];
        } else {
            self.user.homepageURL = nil;
        }
    }
    
    HTMLElement *userPictureImage = [self.node awful_firstNodeMatchingCachedSelector:@"div.userpic img"];
    if (userPictureImage) {
        self.user.profilePictureURL = [NSURL URLWithString:userPictureImage[@"src"]];
    }
    
    HTMLElement *additionalList = [self.node awful_firstNodeMatchingCachedSelector:@"dl.additional"];
    HTMLElement *postCountDefinition = [additionalList awful_firstNodeMatchingCachedSelector:@"dd:nth-of-type(2)"];
    NSString *postCountText = [postCountDefinition.children.firstObject textContent];
    if (postCountText.length > 0) {
        NSInteger postCount;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postCountText];
        BOOL ok = [scanner scanInteger:&postCount];
        if (ok) {
            self.user.postCount = (int32_t)postCount;
        }
    }
    
    HTMLElement *postRateDefinition = [additionalList awful_firstNodeMatchingCachedSelector:@"dd:nth-of-type(3)"];
    NSString *postRateText = [postRateDefinition.children.firstObject textContent];
    if (postRateText.length > 0) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postRateText];
        BOOL ok = [scanner scanFloat:nil];
        if (ok) {
            self.user.postRate = [scanner.string substringToIndex:scanner.scanLocation];
        }
    }
    
    HTMLElement *lastPostDefinition = [additionalList awful_firstNodeMatchingCachedSelector:@"dd:nth-of-type(4)"];
    NSString *lastPostText = [lastPostDefinition.children.firstObject textContent];
    if (lastPostText.length > 0) {
        NSDate *lastPostDate = [[AwfulCompoundDateParser postDateParser] dateFromString:lastPostText];
        if (lastPostDate) {
            self.user.lastPost = lastPostDate;
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
            self.user.location = definitionText.data;
        } else if ([termText.data hasPrefix:@"Interests"]) {
            self.user.interests = definitionText.data;
        } else if ([termText.data hasPrefix:@"Occupation"]) {
            self.user.occupation = definitionText.data;
        }
    }
}

@end
