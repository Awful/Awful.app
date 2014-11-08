//  PostComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextViewController.h"
#import "AwfulModels.h"
@class Post;
@class Thread;

/**
 * A PostComposeViewController shows a text view for composing or editing a reply to a thread.
 */
@interface PostComposeViewController : ComposeTextViewController

/**
 * Returns an initialized AwfulReplyViewController ready to edit a post. This is one of two designated initializers.
 *
 * @param post         The post to edit.
 * @param originalText The original BBcode text of the post.
 */
- (instancetype)initWithPost:(Post *)post originalText:(NSString *)originalText;

@property (readonly, strong, nonatomic) Post *post;

@property (readonly, copy, nonatomic) NSString *originalText;

/**
 * Returns an initialized AwfulReplyViewController ready to write a new post. This is one of two designated initializers.
 *
 * @param thread     The thread to reply to.
 * @param quotedText The text of any quoted posts. Can be nil.
 */
- (instancetype)initWithThread:(Thread *)thread quotedText:(NSString *)quotedText;

@property (readonly, strong, nonatomic) Thread *thread;

@property (readonly, copy, nonatomic) NSString *quotedText;

/**
 * Returns the post created after submission, or nil if it could not be located.
 */
@property (readonly, strong, nonatomic) Post *reply;

@end
