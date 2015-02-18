//  LepersColonyPageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <AwfulCore/AwfulScraper.h>

/// A LepersColonyPageScraper finds AwfulBan objects from a list of bans and probations.
@interface LepersColonyPageScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSArray *punishments;

@end
