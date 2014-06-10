//  AwfulReplyViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulReplyViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumTweaks.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulPostPreviewViewController.h"
#import "AwfulSettings.h"

@interface AwfulReplyViewController () <UIViewControllerRestoration>

@property (copy, nonatomic) void (^onAppearBlock)(void);

@end

@implementation AwfulReplyViewController

- (id)initWithPost:(AwfulPost *)post originalText:(NSString *)originalText
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _post = post;
    _originalText = [originalText copy];
    self.title = post.thread.title;
    if ([AwfulSettings settings].confirmNewPosts) {
        self.submitButtonItem.title = @"Preview";
    } else {
        self.submitButtonItem.title = @"Save";
    }
	[self updateTweaks];
    return self;
}

- (id)initWithThread:(AwfulThread *)thread quotedText:(NSString *)quotedText
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _thread = thread;
    _quotedText = [quotedText copy];
    self.title = thread.title;
    if ([AwfulSettings settings].confirmNewPosts) {
        self.submitButtonItem.title = @"Preview";
    } else {
        self.submitButtonItem.title = @"Post";
    }
	[self updateTweaks];
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.restorationClass = self.class;
    return self;
}

- (void)updateTweaks
{
	AwfulForumTweaks *tweaks = [AwfulForumTweaks tweaksForForumId:self.forum.forumID];
	
	//Apply autocorrection tweaks to text view
	self.textView.autocapitalizationType = tweaks.autocapitalizationType;
    self.textView.autocorrectionType = tweaks.autocorrectionType;
    self.textView.spellCheckingType = tweaks.spellCheckingType;
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.textView.text.length == 0) {
        self.textView.text = self.originalText ?: self.quotedText;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.onAppearBlock) {
        self.onAppearBlock();
        self.onAppearBlock = nil;
    }
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentThemeForForum:self.forum];
}

- (AwfulForum *)forum
{
    if (self.post) {
        return self.post.thread.forum;
    } else if (self.thread) {
        return self.thread.forum;
    } else {
        return nil;
    }
}

- (void)shouldSubmitHandler:(void(^)(BOOL ok))handler
{
    if (![AwfulSettings settings].confirmNewPosts) return handler(YES);
    
    AwfulPostPreviewViewController *preview;
    if (self.thread) {
        preview = [[AwfulPostPreviewViewController alloc] initWithThread:self.thread BBcode:self.textView.attributedText];
    } else if (self.post) {
        preview = [[AwfulPostPreviewViewController alloc] initWithPost:self.post BBcode:self.textView.attributedText];
    }
    
    preview.submitBlock = ^{ handler(YES); };
    self.onAppearBlock = ^{ handler(NO); };
    [self.navigationController pushViewController:preview animated:YES];
}

- (NSString *)submissionInProgressTitle
{
    return self.post ? @"Saving…" : @"Posting…";
}

- (void)submitComposition:(NSString *)composition completionHandler:(void (^)(BOOL success))completionHandler
{
    if (self.post) {
        [[AwfulForumsClient client] editPost:self.post setBBcode:composition andThen:^(NSError *error) {
            if (error) {
                completionHandler(NO);
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            } else {
                completionHandler(YES);
            }
        }];
    } else if (self.thread) {
        __weak __typeof__(self) weakSelf = self;
        [[AwfulForumsClient client] replyToThread:self.thread withBBcode:composition andThen:^(NSError *error, AwfulPost *post) {
            __typeof__(self) self = weakSelf;
            if (error) {
                completionHandler(NO);
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            } else {
                completionHandler(YES);
                if (post) {
                    self->_reply = post;
                }
            }
        }];
    } else {
        NSAssert(NO, @"nothing to submit?");
    }
}

- (void)cancel
{
    if (self.post) {
        if (self.delegate) {
            AwfulActionSheet *actionSheet = [AwfulActionSheet new];
            [actionSheet addDestructiveButtonWithTitle:@"Delete Edit" block:^{
                [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:NO shouldKeepDraft:NO];
            }];
            [actionSheet addButtonWithTitle:@"Save Draft" block:^{
                [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:NO shouldKeepDraft:YES];
            }];
            [actionSheet addCancelButtonWithTitle:@"Cancel"];
            [actionSheet showFromBarButtonItem:self.cancelButtonItem animated:YES];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } else if (self.thread) {
        [super cancel];
    } else {
        NSAssert(NO, @"unexpected cancellation without post or thread");
    }
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    NSString *postID = [coder decodeObjectForKey:PostIDKey];
    NSString *threadID = [coder decodeObjectForKey:ThreadIDKey];
    AwfulReplyViewController *replyViewController;
    if (postID) {
        AwfulPost *post = [AwfulPost firstOrNewPostWithPostID:postID
                                       inManagedObjectContext:[AwfulAppDelegate instance].managedObjectContext];
        NSString *originalText = [coder decodeObjectForKey:OriginalTextKey];
        replyViewController = [[AwfulReplyViewController alloc] initWithPost:post originalText:originalText];
    } else if (threadID) {
        AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID
                                                 inManagedObjectContext:[AwfulAppDelegate instance].managedObjectContext];
        NSString *quotedText = [coder decodeObjectForKey:QuotedTextKey];
        replyViewController = [[AwfulReplyViewController alloc] initWithThread:thread quotedText:quotedText];
    } else {
        NSLog(@"%s no post or thread at %@; skipping restore",
              __PRETTY_FUNCTION__, [identifierComponents componentsJoinedByString:@"/"]);
        return nil;
    }
    replyViewController.restorationIdentifier = identifierComponents.lastObject;
    return replyViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    if (self.thread) {
        [coder encodeObject:self.thread.threadID forKey:ThreadIDKey];
        [coder encodeObject:self.quotedText forKey:QuotedTextKey];
    } else if (self.post) {
        [coder encodeObject:self.post.postID forKey:PostIDKey];
        [coder encodeObject:self.originalText forKey:OriginalTextKey];
    }
}

static NSString * const PostIDKey = @"AwfulPostID";
static NSString * const OriginalTextKey = @"AwfulOriginalText";
static NSString * const ThreadIDKey = @"AwfulThreadID";
static NSString * const QuotedTextKey = @"AwfulQuotedText";

@end
