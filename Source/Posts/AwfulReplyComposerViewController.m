//
//  AwfulReplyViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyComposerViewController.h"
#import "AwfulModels.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "NSString+CollapseWhitespace.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulReplyComposerViewController ()
@end

@implementation AwfulReplyComposerViewController



- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents
{
    self.thread = thread;
    self.post = nil;
    self.composerTextView.text = contents;
    self.title = [thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Reply";
    self.images = [NSMutableDictionary new];
}



- (void)completeReply:(NSString *)reply
    withImagePlaceholderResults:(NSArray *)placeholderResults
    replacementURLs:(NSDictionary *)replacementURLs
{
    [SVProgressHUD showWithStatus:self.thread ? @"Replying…" : @"Editing…"
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
    
    [self sendReply:reply];
    
    [self.composerTextView resignFirstResponder];
}

- (void)sendReply:(NSString *)reply
{
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
                 [self.delegate composerViewController:self didSend:self.thread];
             }];
    self.networkOperation = op;
}



@end
