//
//  AwfulScrapeOperation.h
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulScrapeOperation : NSOperation

@property (readonly, strong) NSError *error;

@property (readonly, strong) NSDictionary *scrapings;

// For use without depending on an HTTP operation.
- (id)initWithResponseData:(NSData *)data;

@end

extern const struct AwfulScrapingsKeys
{
    __unsafe_unretained NSString * const Forums;
} AwfulScrapingsKeys;

@interface AwfulForumListScrapeOperation : AwfulScrapeOperation @end
