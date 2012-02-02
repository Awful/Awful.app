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

@interface AwfulPost : NSObject {
    NSString *_postID;
    NSString *_postDate;
    NSString *_authorName;
    AwfulUserType _authorType;
    NSURL *_avatarURL;
    NSString *_editedStr;
    NSString *_formattedHTML;
    
    NSString *_rawContent;
    NSString *_markSeenLink;
    BOOL _isOP;
    BOOL _canEdit;
}

@property (nonatomic, strong) NSString *postID;
@property (nonatomic, strong) NSString *postDate;
@property (nonatomic, strong) NSString *authorName;
@property AwfulUserType authorType;
@property (nonatomic, strong) NSURL *avatarURL;
@property (nonatomic, strong) NSString *editedStr;
@property (nonatomic, strong) NSString *formattedHTML;
@property (nonatomic, strong) NSString *rawContent;
@property (nonatomic, strong) NSString *markSeenLink;
@property BOOL isOP;
@property BOOL canEdit;

@end
