//
//  AwfulWebCache.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AwfulWebCache : NSURLCache {

}

-(BOOL)smilieCheck : (NSURLRequest *)request;
-(BOOL)cssCheck : (NSURLRequest *)request;
+(BOOL)isURLAllowed : (NSURLRequest *)request;
+(NSArray *)newThumbnailWhitelist;

@end
