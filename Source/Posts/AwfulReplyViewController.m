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
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation AwfulReplyViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithPost:(AwfulPost *)post originalText:(NSString *)originalText
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _post = post;
        _originalText = [originalText copy];
        self.title = post.thread.title;
    }
    return self;
}

- (id)initWithThread:(AwfulThread *)thread quotedText:(NSString *)quotedText
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _thread = thread;
        _quotedText = [quotedText copy];
        self.title = thread.title;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.restorationClass = self.class;
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:AwfulSettingsDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTweaks
{
	AwfulForumTweaks *tweaks = [AwfulForumTweaks tweaksForForumId:self.forum.forumID];
	self.textView.autocapitalizationType = tweaks.autocapitalizationType;
    self.textView.autocorrectionType = tweaks.autocorrectionType;
    self.textView.spellCheckingType = tweaks.spellCheckingType;
}

- (void)updateSubmitButtonTitle
{
    if ([AwfulSettings settings].confirmNewPosts) {
        self.submitButtonItem.title = @"Preview";
    } else {
        if (self.post) {
            self.submitButtonItem.title = @"Save";
        } else {
            self.submitButtonItem.title = @"Post";
        }
    }
}

- (void)settingsDidChange:(NSNotification *)notification
{
    [self updateSubmitButtonTitle];
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateTweaks];
    [self updateSubmitButtonTitle];
    if (self.textView.text.length == 0) {
        self.textView.text = self.originalText ?: self.quotedText;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.longPressRecognizer && ![AwfulSettings settings].confirmNewPosts) {
        self.longPressRecognizer = [UILongPressGestureRecognizer new];
        [self.longPressRecognizer addTarget:self action:@selector(didLongPressNextButtonItem:)];
        
        // HACK: Private API.
        UIView *itemView;
        if ([self.submitButtonItem respondsToSelector:@selector(view)]) {
            itemView = [self.submitButtonItem valueForKey:@"view"];
        }
        [itemView addGestureRecognizer:self.longPressRecognizer];
    }
    
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
    if ([AwfulSettings settings].confirmNewPosts) {
        [self previewPostWithSubmitBlock:^{ handler(YES); } cancelBlock:^{ handler(NO); }];
    } else {
        handler(YES);
    }
}

- (void)previewPostWithSubmitBlock:(void (^)(void))submitBlock cancelBlock:(void (^)(void))cancelBlock
{
    AwfulPostPreviewViewController *preview;
    if (self.thread) {
        preview = [[AwfulPostPreviewViewController alloc] initWithThread:self.thread BBcode:self.textView.attributedText];
    } else if (self.post) {
        preview = [[AwfulPostPreviewViewController alloc] initWithPost:self.post BBcode:self.textView.attributedText];
    }
    
    preview.submitBlock = submitBlock;
    self.onAppearBlock = cancelBlock;
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

- (void)didLongPressNextButtonItem:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        AwfulActionSheet *actionSheet = [AwfulActionSheet new];
        [actionSheet addButtonWithTitle:@"Preview" block:^{
            [self previewPostWithSubmitBlock:^{
                
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self.submitButtonItem.target performSelector:self.submitButtonItem.action withObject:self];
                #pragma clang diagnostic pop
                
            } cancelBlock:nil];
        }];
        [actionSheet addCancelButtonWithTitle:@"Cancel"];
        [actionSheet showFromBarButtonItem:self.submitButtonItem animated:YES];
    }
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    NSString *postID = [coder decodeObjectForKey:PostIDKey];
    NSString *threadID = [coder decodeObjectForKey:ThreadIDKey];
    AwfulReplyViewController *replyViewController;
    if (postID) {
        AwfulPost *post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:managedObjectContext];
        NSString *originalText = [coder decodeObjectForKey:OriginalTextKey];
        replyViewController = [[AwfulReplyViewController alloc] initWithPost:post originalText:originalText];
    } else if (threadID) {
        AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID inManagedObjectContext:managedObjectContext];
        NSString *quotedText = [coder decodeObjectForKey:QuotedTextKey];
        replyViewController = [[AwfulReplyViewController alloc] initWithThread:thread quotedText:quotedText];
    } else {
        NSLog(@"%s no post or thread at %@; skipping restore", __PRETTY_FUNCTION__, [identifierComponents componentsJoinedByString:@"/"]);
        return nil;
    }
    replyViewController.restorationIdentifier = identifierComponents.lastObject;
    NSError *error;
    if (![managedObjectContext save:&error]) {
        NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
    }
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
