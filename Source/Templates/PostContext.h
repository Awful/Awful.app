//
//  PostContext.h
//  Awful
//
//  Created by Nolan Waite on 12-04-12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulPost;

@interface PostContext : NSObject

// Designated initializer.
- (id)initWithPost:(AwfulPost *)post;

@property (strong) NSString *postID;
@property (assign) BOOL isOP;
@property (strong) NSString *avatarURL;
@property (assign) BOOL isMod;
@property (assign) BOOL isAdmin;
@property (strong) NSString *posterName;
@property (strong) NSString *postDate;
@property (strong) NSString *regDate;

// either 'altcolor1', 'altcolor2', 'seen1', or 'seen2' depending on the post index (even/odd)
@property (strong) NSString *altCSSClass;

@property (strong) NSString *postBody;

@end
