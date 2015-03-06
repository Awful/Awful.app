//  AwfulForm.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;
@import Foundation;
@import HTMLReader;

/// Describes an HTML form and helps prepare it for submission.
@interface AwfulForm : NSObject

/// @param element The <form> element representing the form.
- (instancetype)initWithElement:(HTMLElement *)element NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) HTMLElement *element;

/// The name of the form in markup.
@property (readonly, copy, nonatomic) NSString *name;

/// The HTTP method suitable for submitting the form.
@property (readonly, copy, nonatomic) NSString *HTTPMethod;

/// The URL to which the form should be submitted.
@property (readonly, strong, nonatomic) NSURL *submissionURL;

/// Finds all thread tags in the form and updates a managed object context with the findings.
- (void)scrapeThreadTagsIntoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/// An array of AwfulThreadTag objects found in the form. Returns nil if -scrapeThreadTagsIntoMangagedObjectContext: has never been called. Returns an empty array if no thread tags are found.
@property (readonly, copy, nonatomic) NSArray *threadTags;

/// The key for the selected thread tag.
@property (readonly, copy, nonatomic) NSString *selectedThreadTagKey;

/// An array of secondary AwfulThreadTag objects found in the form. Returns nil if -scrapeThreadTagsIntoMangagedObjectContext: has never been called. Returns an empty array if no thread tags are found.
@property (readonly, copy, nonatomic) NSArray *secondaryThreadTags;

/// The key for the selected secondary thread tag.
@property (readonly, copy, nonatomic) NSString *selectedSecondaryThreadTagKey;

/**
    A dictionary of parameters necessary (but perhaps insufficient) to submit the form.
 
    Returned as a mutable dictionary under the presumption that the caller will further modify the dictionary in prepration for submission.
 */
- (NSMutableDictionary *)recommendedParameters;

/// A dictionary of all parameters in the form.
@property (readonly, copy, nonatomic) NSDictionary *allParameters;

@end
