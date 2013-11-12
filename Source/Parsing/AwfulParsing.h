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


@interface SuccessfulReplyInfo : ParsedInfo

@property (readonly, copy, nonatomic) NSString *postID;
@property (readonly, nonatomic) BOOL lastPage;

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
