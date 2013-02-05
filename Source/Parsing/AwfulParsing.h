//
//  AwfulParsing.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-08.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ParsedInfo : NSObject

// Designated initializer.
- (id)initWithHTMLData:(NSData *)htmlData;

@property (readonly, copy, nonatomic) NSData *htmlData;

- (void)applyToObject:(id)object;

@end


@interface ProfileParsedInfo : ParsedInfo

@property (copy, nonatomic) NSString *userID;

@property (readonly, copy, nonatomic) NSString *username;

@property (readonly, nonatomic) NSDate *regdate;

@property (readonly, nonatomic) NSURL *avatar;

@property (readonly, copy, nonatomic) NSString *customTitle;

@property (readonly, copy, nonatomic) NSString *aboutMe;

@property (readonly, copy, nonatomic) NSString *aimName;

@property (readonly, copy, nonatomic) NSString *gender;

@property (readonly, nonatomic) NSURL *homepage;

@property (readonly, copy, nonatomic) NSString *icqName;

@property (readonly, copy, nonatomic) NSString *interests;

@property (readonly, nonatomic) NSDate *lastPost;

@property (readonly, copy, nonatomic) NSString *location;

@property (readonly, copy, nonatomic) NSString *occupation;

@property (readonly, nonatomic) NSInteger postCount;

@property (readonly, copy, nonatomic) NSString *postRate;

@property (readonly, nonatomic) NSURL *profilePicture;

@property (readonly, copy, nonatomic) NSString *yahooName;

@end


@interface ReplyFormParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *formkey;

@property (readonly, copy, nonatomic) NSString *formCookie;

@property (readonly, copy, nonatomic) NSString *bookmark;

@property (readonly, copy, nonatomic) NSString *text;

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


@interface UserParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *username;

@property (readonly, copy, nonatomic) NSString *userID;

@property (readonly, nonatomic) NSDate *regdate;

@property (readonly, nonatomic) BOOL moderator;

@property (readonly, nonatomic) BOOL administrator;

@property (readonly, nonatomic) BOOL originalPoster;

@property (readonly, copy, nonatomic) NSString *customTitle;

@property (readonly, nonatomic) NSURL *avatarURL;

@end


@interface ThreadParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *forumID;

@property (readonly, copy, nonatomic) NSString *threadID;

@property (readonly, copy, nonatomic) NSString *title;

@property (readonly, nonatomic) BOOL isSticky;

@property (readonly, nonatomic) NSURL *threadIconImageURL;

@property (readonly, nonatomic) NSURL *threadIconImageURL2;

@property (readonly, nonatomic) UserParsedInfo *author;

@property (readonly, nonatomic) BOOL seen;

@property (readonly, nonatomic) BOOL isClosed;

@property (readonly, nonatomic) NSInteger starCategory;

@property (readonly, nonatomic) BOOL isBookmarked;

// Defaults to -1.
@property (readonly, nonatomic) NSInteger totalUnreadPosts;

@property (readonly, nonatomic) NSInteger totalReplies;

@property (readonly, nonatomic) NSInteger threadVotes;

@property (readonly, nonatomic) NSDecimalNumber *threadRating;

@property (readonly, copy, nonatomic) NSString *lastPostAuthorName;

@property (readonly, nonatomic) NSDate *lastPostDate;

+ (NSArray *)threadsWithHTMLData:(NSData *)htmlData;

@end


@interface PostParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *postID;

@property (readonly, copy, nonatomic) NSString *threadIndex;

@property (readonly, nonatomic) NSDate *postDate;

@property (readonly, nonatomic) UserParsedInfo *author;

@property (readonly, getter=isEditable, nonatomic) BOOL editable;

@property (readonly, nonatomic) BOOL beenSeen;

@property (readonly, copy, nonatomic) NSString *innerHTML;

@end


@interface PageParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSArray *posts;

@property (readonly, nonatomic) NSInteger pageNumber;

@property (readonly, nonatomic) NSInteger pagesInThread;

@property (readonly, copy, nonatomic) NSString *advertisementHTML;

@property (readonly, copy, nonatomic) NSString *forumID;

@property (readonly, copy, nonatomic) NSString *forumName;

@property (readonly, copy, nonatomic) NSString *threadID;

@property (readonly, copy, nonatomic) NSString *threadTitle;

@property (readonly, getter=isThreadLocked, nonatomic) BOOL threadLocked;

@property (readonly, getter=isThreadBookmarked, nonatomic) BOOL threadBookmarked;

@end


@interface SuccessfulReplyInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *postID;

@property (readonly, nonatomic) BOOL lastPage;

@end


typedef enum {
    AwfulBanTypeUnknown = 0,
    AwfulBanTypeProbation,
    AwfulBanTypeBan,
    AwfulBanTypeAutoban,
    AwfulBanTypePermaban
} AwfulBanType;


@interface BanParsedInfo : ParsedInfo

@property (readonly, nonatomic) AwfulBanType banType;

@property (readonly, copy, nonatomic) NSString *postID;

@property (readonly, nonatomic) NSDate *banDate;

@property (readonly, copy, nonatomic) NSString *bannedUserID;

@property (readonly, copy, nonatomic) NSString *bannedUserName;

@property (readonly, copy, nonatomic) NSString *banReason;

@property (readonly, copy, nonatomic) NSString *requesterUserID;

@property (readonly, copy, nonatomic) NSString *requesterUserName;

@property (readonly, copy, nonatomic) NSString *approverUserID;

@property (readonly, copy, nonatomic) NSString *approverUserName;

+ (NSArray *)bansWithHTMLData:(NSData *)htmlData;

@end
