//  AwfulAuthorScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"
#import <HTMLReader/HTMLReader.h>

@interface AwfulAuthorScraper : NSObject

- (AwfulUser *)scrapeAuthorFromNode:(HTMLNode *)node
           intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
