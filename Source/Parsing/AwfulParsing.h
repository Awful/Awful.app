//  AwfulParsing.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

@interface ParsedInfo : NSObject

// Designated initializer.
- (id)initWithHTMLData:(NSData *)htmlData;

@property (readonly, copy, nonatomic) NSData *htmlData;

- (void)applyToObject:(id)object;

@end


@interface ReplyFormParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *formkey;
@property (readonly, copy, nonatomic) NSString *formCookie;
@property (readonly, copy, nonatomic) NSString *bookmark;
@property (readonly, copy, nonatomic) NSString *text;

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
@property (readonly, copy, nonatomic) NSString *customTitleHTML;
@property (readonly, nonatomic) BOOL canReceivePrivateMessages;

@end


@interface SuccessfulReplyInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *postID;
@property (readonly, nonatomic) BOOL lastPage;

@end


typedef NS_ENUM(NSInteger, AwfulBanType) {
    AwfulBanTypeUnknown = 0,
    AwfulBanTypeProbation,
    AwfulBanTypeBan,
    AwfulBanTypeAutoban,
    AwfulBanTypePermaban
};


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


@interface ComposePrivateMessageParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSDictionary *postIcons;
@property (readonly, copy, nonatomic) NSArray *postIconIDs;
@property (readonly, copy, nonatomic) NSDictionary *secondaryIcons;
@property (readonly, copy, nonatomic) NSArray *secondaryIconIDs;
@property (readonly, copy, nonatomic) NSString *secondaryIconKey;
@property (readonly, copy, nonatomic) NSString *selectedSecondaryIconID;
@property (readonly, copy, nonatomic) NSString *text;

@end


@interface NewThreadFormParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *formkey;
@property (readonly, copy, nonatomic) NSString *formCookie;
@property (readonly, copy, nonatomic) NSString *automaticallyParseURLs;
@property (readonly, copy, nonatomic) NSString *bookmarkThread;

@end


@interface SuccessfulNewThreadParsedInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *threadID;

@end
