//  ProfileScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ProfileScraper.h"
#import "AuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulScanner.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface ProfileScraper ()

@property (strong, nonatomic) Profile *profile;

@end

@implementation ProfileScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    AuthorScraper *authorScraper = [AuthorScraper scrapeNode:self.node intoManagedObjectContext:self.managedObjectContext];
    if (!authorScraper.author) {
        NSString *message = @"Failed parsing user profile; could not find either username or user ID";
        self.error = [NSError errorWithDomain:AwfulCoreError.domain code:AwfulCoreError.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    self.profile = authorScraper.author.profile;
    if (!self.profile) {
        self.profile = [Profile insertIntoManagedObjectContextWithContext:self.managedObjectContext];
        self.profile.user = authorScraper.author;
    }
    
    HTMLElement *infoParagraph = [self.node firstNodeMatchingSelector:@"td.info p:first-of-type"];
    if (infoParagraph) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:infoParagraph.innerHTML];
        [scanner scanUpToString:@"claims to be a " intoString:nil];
        [scanner scanString:@"claims to be a " intoString:nil];
        NSString *gender;
        BOOL ok = [scanner scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&gender];
        if (ok) {
            self.profile.gender = gender;
        }
    }
    
    HTMLElement *aboutParagraph = [self.node firstNodeMatchingSelector:@"td.info p:nth-of-type(2)"];
    if (aboutParagraph) {
        self.profile.aboutMe = aboutParagraph.innerHTML;
    }
    
    HTMLElement *messageLink = [self.node firstNodeMatchingSelector:@"dl.contacts dt.pm + dd a"];
    self.profile.user.canReceivePrivateMessages = !!messageLink;
    
    Class HTMLTextNode = NSClassFromString(@"HTMLTextNode");
    
    HTMLElement *ICQDefinition = [self.node firstNodeMatchingSelector:@"dl.contacts dt.icq + dd"];
    if (ICQDefinition) {
        NSString *ICQText = [ICQDefinition.children.firstObject textContent];
        if (ICQDefinition.numberOfChildren == 1 && [ICQDefinition.children[0] isKindOfClass:HTMLTextNode]) {
            self.profile.icqName = ICQText;
        } else {
            self.profile.icqName = nil;
        }
    }
    
    HTMLElement *AIMDefinition = [self.node firstNodeMatchingSelector:@"dl.contacts dt.aim + dd"];
    if (AIMDefinition) {
        NSString *AIMText = [AIMDefinition.children.firstObject textContent];
        if (AIMDefinition.numberOfChildren == 1 && [AIMDefinition.children[0] isKindOfClass:HTMLTextNode]) {
            self.profile.aimName = AIMText;
        } else {
            self.profile.aimName = nil;
        }
    }
    
    HTMLElement *yahooDefinition = [self.node firstNodeMatchingSelector:@"dl.contacts dt.yahoo + dd"];
    if (yahooDefinition) {
        NSString *yahooText = [yahooDefinition.children.firstObject textContent];
        if (yahooDefinition.numberOfChildren == 1 && [yahooDefinition.children[0] isKindOfClass:HTMLTextNode]) {
            self.profile.yahooName = yahooText;
        } else {
            self.profile.yahooName = nil;
        }
    }
    
    HTMLElement *homepageDefinition = [self.node firstNodeMatchingSelector:@"dl.contacts dt.homepage + dd"];
    if (homepageDefinition) {
        NSString *homepageText = [homepageDefinition.children.firstObject textContent];
        if (homepageText.length > 0) {
            self.profile.homepageURL = [NSURL URLWithString:homepageText];
        } else {
            self.profile.homepageURL = nil;
        }
    }
    
    HTMLElement *userPictureImage = [self.node firstNodeMatchingSelector:@"div.userpic img"];
    if (userPictureImage) {
        self.profile.profilePictureURL = [NSURL URLWithString:userPictureImage[@"src"]];
    }
    
    HTMLElement *additionalList = [self.node firstNodeMatchingSelector:@"dl.additional"];
    HTMLElement *postCountDefinition = [additionalList firstNodeMatchingSelector:@"dd:nth-of-type(2)"];
    NSString *postCountText = [postCountDefinition.children.firstObject textContent];
    if (postCountText.length > 0) {
        NSInteger postCount;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postCountText];
        BOOL ok = [scanner scanInteger:&postCount];
        if (ok) {
            self.profile.postCount = (int32_t)postCount;
        }
    }
    
    HTMLElement *postRateDefinition = [additionalList firstNodeMatchingSelector:@"dd:nth-of-type(3)"];
    NSString *postRateText = [postRateDefinition.children.firstObject textContent];
    if (postRateText.length > 0) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:postRateText];
        BOOL ok = [scanner scanFloat:nil];
        if (ok) {
            self.profile.postRate = [scanner.string substringToIndex:scanner.scanLocation];
        }
    }
    
    HTMLElement *lastPostDefinition = [additionalList firstNodeMatchingSelector:@"dd:nth-of-type(4)"];
    NSString *lastPostText = [lastPostDefinition.children.firstObject textContent];
    if (lastPostText.length > 0) {
        NSDate *lastPostDate = [[AwfulCompoundDateParser postDateParser] dateFromString:lastPostText];
        if (lastPostDate) {
            self.profile.lastPostDate = lastPostDate;
        }
    }
    
    NSArray *remainingAdditionalInfo = [additionalList.children.array subarrayWithRange:NSMakeRange(4, additionalList.numberOfChildren - 4)];
    for (NSUInteger i = 0; i < remainingAdditionalInfo.count; i++) {
        HTMLElement *term = remainingAdditionalInfo[i];
        if (!([term isKindOfClass:[HTMLElement class]] && [term.tagName isEqualToString:@"dt"])) continue;
        HTMLNode *termText = term.children.firstObject;
        if (![termText isKindOfClass:HTMLTextNode]) continue;
        HTMLElement *definition = remainingAdditionalInfo[++i];
        HTMLNode *definitionText = definition.children.firstObject;
        if (![definitionText isKindOfClass:HTMLTextNode]) continue;
        if ([termText.textContent hasPrefix:@"Location"]) {
            self.profile.location = definitionText.textContent;
        } else if ([termText.textContent hasPrefix:@"Interests"]) {
            self.profile.interests = definitionText.textContent;
        } else if ([termText.textContent hasPrefix:@"Occupation"]) {
            self.profile.occupation = definitionText.textContent;
        }
    }
}

@end
