//
//  AwfulJSONOrScrapeOperation.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-09.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AFHTTPRequestOperation.h"

// Parses JSON or scrapes HTML, whichever format the response takes.
@interface AwfulJSONOrScrapeOperation : AFHTTPRequestOperation

// Whichever of the following two properties is not nil will be passed in to the success callback
// as the responseObject.

// An NSArray or NSDictionary if the response is JSON, or nil otherwise.
@property (readonly, nonatomic) id responseJSON;

// The result of calling createParsedInfoBlock if the response is HTML, or nil otherwise.
@property (readonly, nonatomic) id responseParsedInfo;

// A block that turns UTF-8 HTML data into parsed info. Runs on an arbitrary background queue.
@property (copy, nonatomic) id (^createParsedInfoBlock)(NSData *data);

@end
