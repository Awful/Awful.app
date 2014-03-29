//  AwfulLepersColonyPageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"

/**
 * An AwfulLepersColonyPageScraper finds AwfulBan objects from a list of bans and probations.
 */
@interface AwfulLepersColonyPageScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSArray *bans;

@end
