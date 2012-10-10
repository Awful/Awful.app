//
//  AwfulParsing.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-08.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AwfulStringEncoding.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "XPathQuery.h"

// XPath boilerplate to handle HTML class attribute.
//
//   NSString *xpath = @"//div[" HAS_CLASS(breadcrumbs) "]";
#define HAS_CLASS(name) "contains(concat(' ', normalize-space(@class), ' '), ' " #name "')"


@interface ParsedUserInfo : NSObject

- (id)initWithHTMLData:(NSData *)html;

@property (readonly, copy, nonatomic) NSData *htmlData;

@property (readonly, copy, nonatomic) NSString *userID;

@property (readonly, copy, nonatomic) NSString *username;

@end
