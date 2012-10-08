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
