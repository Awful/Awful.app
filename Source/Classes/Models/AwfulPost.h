//
//  AwfulPost.h
//  Awful
//
//  Created by Sean Berry on 7/31/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    AwfulUserTypeNormal = 0,
    AwfulUserTypeMod,
    AwfulUserTypeAdmin
} AwfulUserType;

@interface AwfulPost : NSObject

@property (nonatomic, strong) NSString *postID;
@property (nonatomic, strong) NSString *postDate;
@property (nonatomic, strong) NSString *posterName;
@property AwfulUserType posterType;
@property (nonatomic, strong) NSURL *avatarURL;
@property (nonatomic, strong) NSString *editedStr;
@property (nonatomic, strong) NSString *rawContent;
@property (nonatomic, strong) NSString *markSeenLink;
@property (nonatomic, strong) NSString *altCSSClass;
@property (nonatomic, strong) NSString *postBody;
@property BOOL isOP;
@property BOOL canEdit;
@property BOOL seen;
@property (nonatomic, assign) NSUInteger postIndex;

@end
