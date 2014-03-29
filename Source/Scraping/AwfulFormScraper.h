//  AwfulFormScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
#import "AwfulForm.h"

/**
 * An AwfulFormScraper finds all HTML forms.
 */
@interface AwfulFormScraper : AwfulScraper

@property (readonly, copy, nonatomic) NSArray *forms;

@end
