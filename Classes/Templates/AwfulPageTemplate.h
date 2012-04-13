//
//  AwfulPageTemplate.h
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulPost;
@class AwfulPageDataController;

@interface AwfulPageTemplate : NSObject

-(NSString *)constructHTMLFromPageDataController : (AwfulPageDataController *)dataController;

@end

@interface NSString (AwfulAdditions)

-(NSString *)stringByTrimmingBetweenBeginString : (NSString *)beginString endString : (NSString *)endString;
-(NSString *)stringByRemovingStrings : (NSString *)first, ... NS_REQUIRES_NIL_TERMINATION;
-(NSString *)substringBetweenBeginString : (NSString *)beginString endString : (NSString *)endString;
+ (NSString *)awful_stringResource:(NSString *)name withExtension:(NSString *)extension;

@end