//  LepersColonyPageScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
@class Punishment;

NS_ASSUME_NONNULL_BEGIN

/// A LepersColonyPageScraper finds Punishment objects from a list of bans and probations.
@interface LepersColonyPageScraper : AwfulScraper

@property (readonly, nullable, copy, nonatomic) NSArray<Punishment *> *punishments;

@end

NS_ASSUME_NONNULL_END
