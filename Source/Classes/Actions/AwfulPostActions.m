//
//  AwfulPostActions.m
//  Awful
//
//  Created by Regular Berry on 6/24/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostActions.h"
#import "AwfulPost.h"
#import "AwfulNetworkEngine.h"
#import "AwfulPage.h"
#import "AwfulUtil.h"

typedef enum {
    AwfulPostActionTypeEdit,
    AwfulPostActionTypeQuote,
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
        [self.titles addObject:@"Quote"];
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
    AwfulPostActionType action = buttonIndex;
    if(self.post.canEdit) {
        if(action == AwfulPostActionTypeEdit) {
            [[ApplicationDelegate awfulNetworkEngine] editContentsForPost:self.post onCompletion:^(NSString *contents) {
                self.postContents = contents;
                [self.viewController performSegueWithIdentifier:@"EditPost" sender:self];
            } onError:^(NSError *error) {
                [AwfulUtil requestFailed:error];
            }];
            return;
        }
    } else {
        action++;
    }
    
    if(action == AwfulPostActionTypeQuote) {
        
        [[ApplicationDelegate awfulNetworkEngine] quoteContentsForPost:self.post onCompletion:^(NSString *contents) {
            self.postContents = [contents stringByAppendingString:@"\n"];
            [self.viewController performSegueWithIdentifier:@"QuoteBox" sender:self];
        } onError:^(NSError *error) {
            [AwfulUtil requestFailed:error];
        }];
        return;
        
    } else if(action == AwfulPostActionTypeMarkRead) {
        
        if(self.post.markSeenLink == nil) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not available" message:@"That feature requires you set 'Show an icon next to each post indicating if it has been seen or not' in your forum options" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        } else {
            [[ApplicationDelegate awfulNetworkEngine] processMarkSeenLink:self.post.markSeenLink onCompletion:^(void){
                if([self.viewController isKindOfClass:[AwfulPage class]]) {
                    AwfulPage *page = (AwfulPage *)self.viewController;
                    [page showCompletionMessage:@"Marked up to there."];
                }
            } onError:^(NSError *error){
                [AwfulUtil requestFailed:error];
            }];
        }
    }
}

@end
