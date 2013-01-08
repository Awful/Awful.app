//
//  AwfulPMReplyViewController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPMComposerViewController.h"
#import "NSString+CollapseWhitespace.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "AwfulSettings.h"
#import "AwfulAlertView.h"
#import "SVProgressHUD.h"
#import "AwfulHTTPClient+PrivateMessages.h"

@interface AwfulPMComposerViewController ()

@end

@implementation AwfulPMComposerViewController

- (void)replyToPrivateMessage:(AwfulPrivateMessage *)message
{
    //self.thread = thread;
    //self.post = nil;
    self.composerTextView.text = message.content;
    self.title = [message.subject stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    //self.images = [NSMutableDictionary new];
}

- (void)continueDraft:(AwfulPrivateMessage *)draft
{
    self.draft = draft;
    //self.thread = thread;
    //self.post = nil;
    self.composerTextView.text = draft.content;
    self.title = [draft.subject stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    //self.images = [NSMutableDictionary new];
}

- (void)hitSend
{
    if (self.imageUploadCancelToken) return;
    [self.composerTextView resignFirstResponder];
    self.composerTextView.userInteractionEnabled = NO;
    if (AwfulSettings.settings.confirmBeforeReplying) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Send Message?";
        alert.message = @"No one cares what you think and you should "
        "probably kill yourself. Want to send your pointless message anyway?";
        [alert addCancelButtonWithTitle:@"Nope"
                                  block:^{ [self.composerTextView becomeFirstResponder]; }];
        [alert addButtonWithTitle:self.sendButton.title block:^{ [self send]; }];
        [alert show];
    } else {
        [self send];
    }
}

- (void)hitCancel
{
    if (self.imageUploadCancelToken) return;
    [self.composerTextView resignFirstResponder];
    self.composerTextView.userInteractionEnabled = NO;
    if (AwfulSettings.settings.confirmBeforeReplying) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Save draft?";
        alert.message = @"This is a piece of shit and you should "
        "spare yourself embarrassment and just delete it.";
        [alert addCancelButtonWithTitle:@"Delete" block:^{  }];
        [alert addButtonWithTitle:@"Save" block:^{ [self send]; }];
        [alert show];
    } else {
        [self send];
    }
}

- (void)send
{
    [self.networkOperation cancel];
    
    NSString *message = self.composerTextView.text;
    NSMutableArray *imageKeys = [NSMutableArray new];
    NSString *pattern = @"\\[(t?img)\\](imgur://(.+)\\.png)\\[/\\1\\]";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error parsing image URL placeholder regex: %@", error);
        return;
    }
    NSArray *placeholderResults = [regex matchesInString:message
                                                 options:0
                                                   range:NSMakeRange(0, [message length])];
    for (NSTextCheckingResult *result in placeholderResults) {
        NSRange rangeOfKey = [result rangeAtIndex:3];
        if (rangeOfKey.location == NSNotFound) continue;
        [imageKeys addObject:[message substringWithRange:rangeOfKey]];
    }
    
    if ([imageKeys count] == 0) {
        [self completeReply:message
withImagePlaceholderResults:placeholderResults
            replacementURLs:nil];
        return;
    }
    [SVProgressHUD showWithStatus:@"Uploading images…"];
    
    NSArray *images = [self.images objectsForKeys:imageKeys notFoundMarker:[NSNull null]];
    self.imageUploadCancelToken = [[ImgurHTTPClient client] uploadImages:images
                                                                 andThen:^(NSError *error,
                                                                           NSArray *urls)
                                   {
                                       self.imageUploadCancelToken = nil;
                                       if (!error) {
                                           [self completeReply:message
                                   withImagePlaceholderResults:placeholderResults
                                               replacementURLs:[NSDictionary dictionaryWithObjects:urls forKeys:imageKeys]];
                                           return;
                                       }
                                       [SVProgressHUD dismiss];
                                       [AwfulAlertView showWithTitle:@"Image Uploading Failed"
                                                               error:error
                                                         buttonTitle:@"Fiddlesticks"];
                                   }];
}

- (void)completeReply:(NSString *)reply
withImagePlaceholderResults:(NSArray *)placeholderResults
      replacementURLs:(NSDictionary *)replacementURLs
{
    [SVProgressHUD showWithStatus:@"Sending…"
                         maskType:SVProgressHUDMaskTypeClear];
    
    if ([placeholderResults count] > 0) {
        NSMutableString *replacedReply = [reply mutableCopy];
        NSInteger offset = 0;
        for (__strong NSTextCheckingResult *result in placeholderResults) {
            result = [result resultByAdjustingRangesWithOffset:offset];
            if ([result rangeAtIndex:3].location == NSNotFound) return;
            NSString *key = [reply substringWithRange:[result rangeAtIndex:3]];
            NSString *url = [replacementURLs[key] absoluteString];
            NSUInteger priorLength = [replacedReply length];
            if (url) {
                NSRange rangeOfURL = [result rangeAtIndex:2];
                rangeOfURL.location += offset;
                [replacedReply replaceCharactersInRange:rangeOfURL withString:url];
            } else {
                NSLog(@"found no associated image URL, so stripping tag %@",
                      [replacedReply substringWithRange:result.range]);
                [replacedReply replaceCharactersInRange:result.range withString:@""];
            }
            offset += ([replacedReply length] - priorLength);
        }
        reply = replacedReply;
    }
    
    [self sendMessage:reply];
    [self.composerTextView resignFirstResponder];
}

- (void)sendMessage:(NSString *)reply
{
    /*
    id op = [[AwfulHTTPClient client] replyToThreadWithID:self.thread.threadID
                                                     text:reply
                                                  andThen:^(NSError *error, NSString *postID)
             {
                 if (error) {
                     [SVProgressHUD dismiss];
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Replied"];
                 [self.delegate replyViewController:self didReplyToThread:self.thread];
             }];
    self.networkOperation = op;
     */
}

@end
