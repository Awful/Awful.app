//  AwfulCore.h
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

FOUNDATION_EXPORT double AwfulCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char AwfulCoreVersionString[];

// Model
#import <AwfulCore/AwfulStarCategory.h>
#import <AwfulCore/AwfulThreadPage.h>
#import <AwfulCore/PunishmentSentence.h>

// Scraping
#import <AwfulCore/AuthorScraper.h>
#import <AwfulCore/AwfulForm.h>
#import <AwfulCore/AwfulForumHierarchyScraper.h>
#import <AwfulCore/AwfulPostScraper.h>
#import <AwfulCore/AwfulPostsPageScraper.h>
#import <AwfulCore/AwfulScraper.h>
#import <AwfulCore/AwfulThreadListScraper.h>
#import <AwfulCore/AwfulUnreadPrivateMessageCountScraper.h>
#import <AwfulCore/LepersColonyPageScraper.h>
#import <AwfulCore/NSURLQueryDictionary.h>
#import <AwfulCore/PrivateMessageFolderScraper.h>
#import <AwfulCore/PrivateMessageScraper.h>
#import <AwfulCore/ProfileScraper.h>
