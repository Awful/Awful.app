//
//  AwfulThreadListScraper.h
//  Awful
//
//  Created by Nolan Waite on 11/4/2013.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <HTMLReader/HTMLReader.h>

@interface AwfulThreadListScraper : NSObject

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error;

@end
