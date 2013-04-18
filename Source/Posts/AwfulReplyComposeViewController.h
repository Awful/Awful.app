//
//  AwfulReplyComposeViewController.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulComposeViewController.h"
#import "AwfulModels.h"

@protocol AwfulReplyComposeViewControllerDelegate;


@interface AwfulReplyComposeViewController : AwfulComposeViewController

@property (weak, nonatomic) id <AwfulReplyComposeViewControllerDelegate> delegate;

- (void)editPost:(AwfulPost *)post
            text:(NSString *)text
imageCacheIdentifier:(id)imageCacheIdentifier;

@property (readonly, nonatomic) AwfulPost *editedPost;

// Create a new reply to a thread.
//
// thread               - The thread to reply to.
// contents             - Textual contents of a reply. For example, this might be a quoted post.
//                        Can be nil.
// imageCacheIdentifier - An identifier returned earlier from -imageCacheIdentifier. Can be nil.
- (void)replyToThread:(AwfulThread *)thread
  withInitialContents:(NSString *)contents
 imageCacheIdentifier:(id)imageCacheIdentifier;

// Saves images added to the reply to a persistent cache. The cache sits in the application's
// Caches folder, so iOS can conceivably erase its contents with no recourse.
//
// Returns an opaque object that can be used when recreating a reply or to delete the cache.
- (id)imageCacheIdentifier;

// Deletes any cached images stored with the given identifier.
+ (void)deleteImageCacheWithIdentifier:(id)imageCacheIdentifier;

@end


@protocol AwfulReplyComposeViewControllerDelegate <NSObject>

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
                   didEditPost:(AwfulPost *)post;

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
              didReplyToThread:(AwfulThread *)thread;

- (void)replyComposeControllerDidCancel:(AwfulReplyComposeViewController *)controller;

@end
