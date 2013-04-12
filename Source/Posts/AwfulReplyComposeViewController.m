//
//  AwfulReplyComposeViewController.m
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulReplyComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulKeyboardBar.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTextView.h"
#import "ImgurHTTPClient.h"
#import "NSFileManager+UserDirectories.h"
#import "NSString+CollapseWhitespace.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulReplyComposeViewController () <UIImagePickerControllerDelegate,
                                               UINavigationControllerDelegate,
                                               UIPopoverControllerDelegate>

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) AwfulThread *thread;
@property (nonatomic) AwfulPost *post;
@property (copy, nonatomic) NSString *imageCacheIdentifier;
@property (nonatomic) NSMutableSet *cachedImages;

@end


@implementation AwfulReplyComposeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.cachedImages = [NSMutableSet new];
    self.sendButton.target = self;
    self.sendButton.action = @selector(didTapSend);
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancel);
    return self;
}

- (void)editPost:(AwfulPost *)post text:(NSString *)text
{
    self.post = post;
    self.thread = nil;
    self.textView.text = text;
    self.title = [post.thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Save";
}

- (void)replyToThread:(AwfulThread *)thread
  withInitialContents:(NSString *)contents
 imageCacheIdentifier:(id)imageCacheIdentifier
{
    self.thread = thread;
    self.post = nil;
    self.textView.text = contents;
    self.title = [thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Reply";
    if (imageCacheIdentifier) {
        self.imageCacheIdentifier = imageCacheIdentifier;
        [self holdPlacesForCachedImages];
    }
}

- (void)holdPlacesForCachedImages
{
    if (!self.imageCacheIdentifier) return;
    NSURL *cacheDirectory = CachedImageDirectoryForIdentifier(self.imageCacheIdentifier);
    NSError *error;
    NSArray *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:cacheDirectory
                                                  includingPropertiesForKeys:nil
                                                                     options:0
                                                                       error:&error];
    if (!urls) {
        NSLog(@"error holding places for cached images in %@: %@", cacheDirectory, error);
        return;
    }
    for (NSURL *url in urls) {
        if (![[url pathExtension] isEqualToString:@"png"]) continue;
        NSString *key = [[url lastPathComponent] stringByDeletingPathExtension];
        self.images[key] = [NSNull null];
        [self.cachedImages addObject:key];
    }
}

- (void)didTapSend
{
    if (self.state != AwfulComposeViewControllerStateReady) return;
    [self.networkOperation cancel];
    [self.textView resignFirstResponder];
    self.textView.userInteractionEnabled = NO;
    if ([AwfulSettings settings].confirmBeforeReplying) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Incoming Forums Superstar";
        alert.message = @"Does my reply offer any significant advice or help "
                         "contribute to the conversation in any fashion?";
        [alert addCancelButtonWithTitle:@"Nope" block:^{
            self.textView.userInteractionEnabled = YES;
            [self.textView becomeFirstResponder];
        }];
        [alert addButtonWithTitle:self.sendButton.title block:^{ [self prepareToSendMessage]; }];
        [alert show];
    } else {
        [self prepareToSendMessage];
    }
}

- (void)prepareToSendMessage
{
    // Need to load any cached images before superclass tries to upload them.
    if (self.imageCacheIdentifier) {
        NSURL *cacheDirectory = CachedImageDirectoryForIdentifier(self.imageCacheIdentifier);
        for (NSString *key in [self.images allKeys]) {
            if (![self.images[key] isEqual:[NSNull null]]) continue;
            NSURL *url = [cacheDirectory URLByAppendingPathComponent:key];
            url = [url URLByAppendingPathExtension:@"png"];
            UIImage *image = [UIImage imageWithContentsOfFile:[url path]];
            if (image) {
                self.images[key] = image;
            }
        }
    }
    [super prepareToSendMessage];
}

- (void)willTransitionToState:(AwfulComposeViewControllerState)state
{
    if (state == AwfulComposeViewControllerStateReady) {
        self.textView.userInteractionEnabled = YES;
        [self.textView becomeFirstResponder];
    } else {
        self.textView.userInteractionEnabled = NO;
        [self.textView resignFirstResponder];
    }
    
    if (state == AwfulComposeViewControllerStateUploadingImages) {
        [SVProgressHUD showWithStatus:@"Uploading images…"];
    } else if (state == AwfulComposeViewControllerStateSending) {
        [SVProgressHUD showWithStatus:self.thread ? @"Replying…" : @"Editing…"
                             maskType:SVProgressHUDMaskTypeClear];
    } else if (state == AwfulComposeViewControllerStateError) {
        [SVProgressHUD dismiss];
    }
}

- (void)send:(NSString *)messageBody
{
    NSOperation *op;
    void (^errorHandler)(NSError*) = ^(NSError *error){
        [SVProgressHUD dismiss];
        [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK" completion:^{
            self.textView.userInteractionEnabled = YES;
        }];
    };
    if (self.thread) {
        op = [[AwfulHTTPClient client] replyToThreadWithID:self.thread.threadID text:messageBody
                                                   andThen:^(NSError *error, NSString *postID)
        {
            if (error) return errorHandler(error);
            [SVProgressHUD showSuccessWithStatus:@"Replied"];
            [self.delegate replyComposeController:self didReplyToThread:self.thread];
        }];
    } else {
        op = [[AwfulHTTPClient client] editPostWithID:self.post.postID text:messageBody
                                              andThen:^(NSError *error)
        {
            if (error) return errorHandler(error);
            [SVProgressHUD showSuccessWithStatus:@"Edited"];
            [self.delegate replyComposeController:self didEditPost:self.post];
        }];
    }
    self.networkOperation = op;
}

- (void)cancel
{
    [super cancel];
    [self.networkOperation cancel];
    if ([SVProgressHUD isVisible]) {
        [SVProgressHUD dismiss];
        self.textView.userInteractionEnabled = YES;
        [self.textView becomeFirstResponder];
    } else {
        [self.delegate replyComposeControllerDidCancel:self];
    }
}

- (id)imageCacheIdentifier
{
    if ([self.images count] == 0 || [self.cachedImages count] == [self.images count]) {
        return _imageCacheIdentifier;
    }
    if (!_imageCacheIdentifier) {
        _imageCacheIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
    }
    NSURL *cacheDirectory = CachedImageDirectoryForIdentifier(_imageCacheIdentifier);
    NSError *error;
    BOOL ok = [[NSFileManager defaultManager] createDirectoryAtURL:cacheDirectory
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error];
    if (!ok) {
        NSLog(@"failed creating image cache folder %@: %@", cacheDirectory, error);
        return nil;
    }
    for (id imageKey in self.images) {
        if ([self.cachedImages containsObject:imageKey]) continue;
        NSData *imageData = UIImagePNGRepresentation(self.images[imageKey]);
        NSURL *url = [cacheDirectory URLByAppendingPathComponent:imageKey];
        url = [url URLByAppendingPathExtension:@"png"];
        ok = [imageData writeToURL:url options:0 error:&error];
        if (!ok) {
            NSLog(@"error caching image %@: %@", imageKey, error);
        }
        if (ok) {
            [self.cachedImages addObject:imageKey];
        }
    }
    return _imageCacheIdentifier;
}

static NSURL *CachedImageDirectoryForIdentifier(id identifier)
{
    NSURL *cacheDirectory = [[NSFileManager defaultManager] cachesDirectory];
    return [cacheDirectory URLByAppendingPathComponent:identifier];
}

+ (void)deleteImageCacheWithIdentifier:(id)imageCacheIdentifier
{
    NSURL *cacheDirectory = [[NSFileManager defaultManager] cachesDirectory];
    NSURL *imageCache = [cacheDirectory URLByAppendingPathComponent:imageCacheIdentifier];
    imageCache = [imageCache URLByStandardizingPath];
    if ([[imageCache pathComponents] count] <= [[cacheDirectory pathComponents] count]) return;
    NSError *error;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtURL:imageCache error:&error];
    if (!ok) {
        NSLog(@"error deleting image cache %@: %@", imageCache, error);
    }
}

@end
