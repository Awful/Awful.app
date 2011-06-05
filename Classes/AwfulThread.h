//
//  AwfulThread.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

enum {
    RATED_SHIT,
    RATED_NOTHING,
    RATED_GOLD
};

@interface AwfulThread : NSObject <NSCoding> {
    NSString *forumTitle;
    NSString *threadTitle;
    NSString *threadID;
    int numUnreadPosts;
    int threadRating;
    int totalReplies;
    BOOL alreadyRead;
    NSString *threadIcon;
    NSString *threadAuthor;
    NSString *killedBy;
    BOOL isStickied;
    BOOL isLocked;
    int category;
}

@property (nonatomic, retain) NSString *forumTitle;
@property (nonatomic, retain) NSString *threadTitle;
@property (nonatomic, retain) NSString *threadID;
@property int numUnreadPosts;
@property int threadRating;
@property int totalReplies;
@property BOOL alreadyRead;
@property (nonatomic, retain) NSString *threadIcon;
@property (nonatomic, retain) NSString *threadAuthor;
@property (nonatomic, retain) NSString *killedBy;
@property BOOL isStickied;
@property BOOL isLocked;
@property int category;

-(NSString *)getThreadTagHTML;

@end
