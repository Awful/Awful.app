//  AwfulReplyViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulReplyViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulHTTPClient.h"
#import "AwfulSettings.h"
#import "AwfulUIKitAndFoundationCategories.h"

@interface AwfulReplyViewController () <UIViewControllerRestoration>

@end

@implementation AwfulReplyViewController

- (id)initWithPost:(AwfulPost *)post originalText:(NSString *)originalText
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _post = post;
    _originalText = [originalText copy];
    self.title = post.thread.title;
    self.submitButtonItem.title = @"Save";
    return self;
}

- (id)initWithThread:(AwfulThread *)thread quotedText:(NSString *)quotedText
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _thread = thread;
    _quotedText = [quotedText copy];
    self.title = thread.title;
    self.submitButtonItem.title = @"Post";
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.restorationClass = self.class;
    return self;
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

- (void)shouldSubmitHandler:(void(^)(BOOL ok))handler
{
    if (![AwfulSettings settings].confirmNewPosts) return handler(YES);
    AwfulAlertView *alert = [AwfulAlertView new];
    if (self.thread) {
        alert.title = @"Post Post Post";
        alert.message = (@"Does my reply offer any significant advice or help "
                         "contribute to the conversation in any fashion?");
    } else if (self.post) {
        alert.title = @"Edit Edit Edit";
        alert.message = (@"After editing, does my reply offer any significant advice or help "
                         "contribute to the conversation in any fashion?");
    }
    [alert addCancelButtonWithTitle:@"No" block:^{
        handler(NO);
    }];
    [alert addButtonWithTitle:(self.thread ? @"Post" : @"Save") block:^{
        handler(YES);
    }];
    [alert show];
}

- (NSString *)submissionInProgressTitle
{
    return self.post ? @"Saving…" : @"Posting…";
}

- (void)submitComposition:(NSString *)composition completionHandler:(void(^)(BOOL success))completionHandler
{
    if (self.post) {
        [[AwfulHTTPClient client] editPostWithID:self.post.postID text:composition andThen:^(NSError *error) {
            if (error) {
                completionHandler(NO);
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            } else {
                completionHandler(YES);
            }
        }];
    } else if (self.thread) {
        __weak __typeof__(self) weakSelf = self;
        [[AwfulHTTPClient client] replyToThreadWithID:self.thread.threadID
                                                 text:composition
                                              andThen:^(NSError *error, NSString *postID)
        {
            __typeof__(self) self = weakSelf;
            if (error) {
                completionHandler(NO);
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            } else {
                completionHandler(YES);
                if (postID) {
                    _reply = [AwfulPost firstOrNewPostWithPostID:postID
                                          inManagedObjectContext:self.thread.managedObjectContext];
                }
            }
        }];
    } else {
        NSLog(@"%s nothing to submit?", __PRETTY_FUNCTION__);
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
        NSLog(@"%s no post or thread; skipping restore", __PRETTY_FUNCTION__);
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
