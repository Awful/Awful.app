//
//  AwfulPost.h
//  Awful
//
//  Created by Sean Berry on 7/31/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
    USER_TYPE_ADMIN,
    USER_TYPE_MOD,
    USER_TYPE_NORMAL
};

@interface PageManager : NSObject
{
    int current;
    int total;
}

@property int current;
@property int total;

@end

@interface AwfulPost : NSObject {
    NSString *postID;
    NSString *postDate;
    NSString *userName;
    NSString *avatar;
    NSString *content;
    NSString *edited;
    int userType;
    BOOL byOP;
    BOOL newest;
    NSString *rawContent;
    NSString *seenLink;
    NSString *postBody;
    BOOL isMod;
    BOOL isAdmin;
    BOOL isLoaded;
    BOOL canEdit;
}

@property (nonatomic, retain) NSString *postID;
@property (nonatomic, retain) NSString *postDate;
@property (nonatomic, retain) NSString *userName;
@property (nonatomic, retain) NSString *avatar;
@property (nonatomic, retain) NSString *content;
@property (nonatomic, retain) NSString *edited;
@property BOOL byOP;
@property BOOL newest;
@property int userType;
@property (nonatomic, retain) NSString *rawContent;
@property (nonatomic, retain) NSString *seenLink;
@property (nonatomic, retain) NSString *postBody;
@property BOOL isMod;
@property BOOL isAdmin;
@property BOOL isLoaded;
@property BOOL canEdit;

@end
