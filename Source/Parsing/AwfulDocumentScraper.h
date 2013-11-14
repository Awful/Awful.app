//  AwfulDocumentScraper.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <CoreData/CoreData.h>
#import <HTMLReader/HTMLReader.h>

@protocol AwfulDocumentScraper <NSObject>

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error;

@end
