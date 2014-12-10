//  PostComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "PostComposeViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumTweaks.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulPostPreviewViewController.h"
#import "AwfulSettings.h"
#import "Awful-Swift.h"

@interface PostComposeViewController () <UIViewControllerRestoration>

@property (copy, nonatomic) void (^onAppearBlock)(void);
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation PostComposeViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithPost:(Post *)post originalText:(NSString *)originalText
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _post = post;
        _originalText = [originalText copy];
        self.title = post.thread.title;
    }
    return self;
}

- (instancetype)initWithThread:(Thread *)thread quotedText:(NSString *)quotedText
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _thread = thread;
        _quotedText = [quotedText copy];
        self.title = thread.title;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
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
	AwfulForumTweaks *tweaks = [AwfulForumTweaks tweaksWithForumID:self.forum.forumID];
	self.textView.autocapitalizationType = tweaks.autocapitalizationType;
    self.textView.autocorrectionType = tweaks.autocorrectionType;
    self.textView.spellCheckingType = tweaks.spellCheckingType;
}

- (void)updateSubmitButtonTitle
{
    if ([AwfulSettings sharedSettings].confirmNewPosts) {
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
    
    if (!self.longPressRecognizer && ![AwfulSettings sharedSettings].confirmNewPosts) {
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

- (Forum *)forum
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
    if ([AwfulSettings sharedSettings].confirmNewPosts) {
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
    __weak __typeof__(self) weakSelf = self;
    
    void (^showError)() = ^(NSError *error) {
        __typeof__(self) self = weakSelf;
        
        // If we're showing a preview, we can't present an alert from self because we'll be detached. Aim for our navigation controller if possible.
        UIViewController *presenter = self.navigationController ?: self;
        [presenter presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
    };
    
    if (self.post) {
        [[AwfulForumsClient client] editPost:self.post setBBcode:composition andThen:^(NSError *error) {
            if (error) {
                completionHandler(NO);
                showError(error);
            } else {
                completionHandler(YES);
            }
        }];
    } else if (self.thread) {
        [[AwfulForumsClient client] replyToThread:self.thread withBBcode:composition andThen:^(NSError *error, Post *post) {
            __typeof__(self) self = weakSelf;
            if (error) {
                completionHandler(NO);
                showError(error);
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
            UIAlertController *actionSheet = [UIAlertController actionSheet];
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"Delete Edit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:NO shouldKeepDraft:NO];
            }]];
            [actionSheet addActionWithTitle:@"Save Draft" handler:^{
                [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:NO shouldKeepDraft:YES];
            }];
            [actionSheet addCancelActionWithHandler:nil];
            [self presentViewController:actionSheet animated:YES completion:nil];
            actionSheet.popoverPresentationController.barButtonItem = self.cancelButtonItem;
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
        UIAlertController *actionSheet = [UIAlertController actionSheet];
        [actionSheet addActionWithTitle:@"Preview" handler:^{
            [self previewPostWithSubmitBlock:^{
                UIBarButtonItem *item = self.submitButtonItem;
                [[UIApplication sharedApplication] sendAction:item.action to:item.target from:self forEvent:nil];
            } cancelBlock:nil];
        }];
        [actionSheet addCancelActionWithHandler:nil];
        [self presentViewController:actionSheet animated:YES completion:nil];
        actionSheet.popoverPresentationController.barButtonItem = self.submitButtonItem;
    }
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    // AwfulObjectKey was introduced in Awful 3.2.
    PostKey *postKey = [coder decodeObjectForKey:PostKeyKey];
    if (!postKey) {
        NSString *postID = [coder decodeObjectForKey:obsolete_PostIDKey];
        if (postID) {
            postKey = [[PostKey alloc] initWithPostID:postID];
        }
    }
    ThreadKey *threadKey = [coder decodeObjectForKey:ThreadKeyKey];
    if (!threadKey) {
        NSString *threadID = [coder decodeObjectForKey:obsolete_ThreadIDKey];
        if (threadID) {
            threadKey = [[ThreadKey alloc] initWithThreadID:threadID];
        }
    }
    PostComposeViewController *replyViewController;
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    if (postKey) {
        Post *post = [Post objectForKey:postKey inManagedObjectContext:managedObjectContext];
        NSString *originalText = [coder decodeObjectForKey:OriginalTextKey];
        replyViewController = [[PostComposeViewController alloc] initWithPost:post originalText:originalText];
    } else if (threadKey) {
        Thread *thread = [Thread objectForKey:threadKey inManagedObjectContext:managedObjectContext];
        NSString *quotedText = [coder decodeObjectForKey:QuotedTextKey];
        replyViewController = [[PostComposeViewController alloc] initWithThread:thread quotedText:quotedText];
    } else {
        NSLog(@"%s no post or thread at %@; skipping restore", __PRETTY_FUNCTION__, [identifierComponents componentsJoinedByString:@"/"]);
        return nil;
    }
    replyViewController.restorationIdentifier = identifierComponents.lastObject;
    return replyViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    if (self.thread) {
        [coder encodeObject:self.thread.objectKey forKey:ThreadKeyKey];
        [coder encodeObject:self.quotedText forKey:QuotedTextKey];
    } else if (self.post) {
        [coder encodeObject:self.post.objectKey forKey:PostKeyKey];
        [coder encodeObject:self.originalText forKey:OriginalTextKey];
    }
}

static NSString * const PostKeyKey = @"PostKey";
static NSString * const obsolete_PostIDKey = @"AwfulPostID";
static NSString * const OriginalTextKey = @"AwfulOriginalText";
static NSString * const ThreadKeyKey = @"ThreadKey";
static NSString * const obsolete_ThreadIDKey = @"AwfulThreadID";
static NSString * const QuotedTextKey = @"AwfulQuotedText";

@end
