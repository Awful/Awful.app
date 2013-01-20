//
//  NSAttributedString+BBCode.h
//  Awful
//
//  Created by me on 1/19/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (BBCode)

+ (NSAttributedString*)attributedStringWithBBCodeString:(NSString*)bbCodeString;

- (NSString*) BBCode;

@end

@interface NSDictionary (AwfulAttributedString)

+ (NSDictionary*)attributeDictionaryWithTag:(NSString*)tag;

@end

static NSString* kAwfulFormatTagKey = @"kAwfulFormatTagKey";