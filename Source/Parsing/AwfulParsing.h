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


@interface ParsedInfo : NSObject

// Designated initializer.
- (id)initWithHTMLData:(NSData *)htmlData;

@property (readonly, copy, nonatomic) NSData *htmlData;

@end


@interface UserParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *userID;

@property (readonly, copy, nonatomic) NSString *username;

- (void)applyToObject:(id)object;

@end


@interface ReplyFormParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *formkey;

@property (readonly, copy, nonatomic) NSString *formCookie;

@property (readonly, copy, nonatomic) NSString *bookmark;

@end


@interface ForumHierarchyParsedInfo : ParsedInfo

@property (readonly, nonatomic) NSArray *categories;

@end


@interface CategoryParsedInfo : ParsedInfo

@property (readonly, nonatomic) NSArray *forums;

@property (readonly, copy, nonatomic) NSString *name;

@property (readonly, copy, nonatomic) NSString *categoryID;

@end


@interface ForumParsedInfo : ParsedInfo

@property (readonly, weak, nonatomic) CategoryParsedInfo *category;

@property (readonly, nonatomic) NSArray *subforums;

@property (readonly, weak, nonatomic) ForumParsedInfo *parentForum;

@property (readonly, copy, nonatomic) NSString *name;

@property (readonly, copy, nonatomic) NSString *forumID;

@end
