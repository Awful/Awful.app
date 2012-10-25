//
//  AwfulPostActions.m
//  Awful
//
//  Created by Regular Berry on 6/24/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostActions.h"
#import "AwfulAppDelegate.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPage.h"

typedef enum {
    AwfulPostActionTypeEdit,
    AwfulPostActionTypeQuote,
    AwfulPostActionTypeCopyPostURL,
    AwfulPostActionTypeMarkRead,
} AwfulPostActionType;

@implementation AwfulPostActions

@synthesize post = _post;
@synthesize page = _page;
@synthesize postContents = _postContents;

-(id)initWithAwfulPost : (AwfulPost *)aPost page : (AwfulPage *)aPage
{
    if((self=[super init])) {
        self.post = aPost;
        self.page = aPage;
        if(self.post.canEdit) {
            [self.titles addObject:@"Edit"];
        }
        if (aPage.thread.canReply) {
            [self.titles addObject:@"Quote"];
        }
        [self.titles addObject:@"Copy post URL"];
        [self.titles addObject:@"Mark read up to here"];
    }
    return self;
}

-(NSString *)getOverallTitle
{
    return [NSString stringWithFormat:@"Actions on %@'s post", self.post.posterName];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (!self.page.thread.canReply) buttonIndex += 1;
    AwfulPostActionType action = buttonIndex;
    if(self.post.canEdit) {
        if(action == AwfulPostActionTypeEdit) {
            [[AwfulHTTPClient client] getTextOfPostWithID:self.post.postID
                                                  andThen:^(NSError *error, NSString *text)
            {
                if (error) {
                    [[AwfulAppDelegate instance] requestFailed:error];
                } else {
                    self.postContents = text;
                    AwfulPage *page = (AwfulPage *)self.viewController;
                    [page editPostWithActions:self];
                }
            }];
            return;
        }
    } else {
        action++;
    }
    
    if(action == AwfulPostActionTypeQuote) {
        
        [[AwfulHTTPClient client] quoteTextOfPostWithID:self.post.postID
                                                andThen:^(NSError *error, NSString *quotedText)
        {
            if (error) {
                [[AwfulAppDelegate instance] requestFailed:error];
            } else {
                self.postContents = [quotedText stringByAppendingString:@"\n"];
                AwfulPage *page = (AwfulPage *)self.viewController;
                [page quotePostWithActions:self];
            }
        }];
        return;
        
    } else if (action == AwfulPostActionTypeCopyPostURL) {
        // TODO there's probably a better place to put this URL
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/showthread.php?threadid=%@&pagenumber=%d#post%@", self.page.threadID, self.page.currentPage, self.post.postID];
        [UIPasteboard generalPasteboard].URL = [NSURL URLWithString:url];
    } else if(action == AwfulPostActionTypeMarkRead) {
        
        if(self.post.markSeenLink == nil) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not available" message:@"That feature requires you set 'Show an icon next to each post indicating if it has been seen or not' in your forum options" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        } else {
            [[AwfulHTTPClient client] processMarkSeenLink:self.post.markSeenLink onCompletion:^(void){
                if([self.viewController isKindOfClass:[AwfulPage class]]) {
                    AwfulPage *page = (AwfulPage *)self.viewController;
                    [page showCompletionMessage:@"Marked up to there"];
                }
            } onError:^(NSError *error){
                [[AwfulAppDelegate instance] requestFailed:error];
            }];
        }
    }
}

@end
