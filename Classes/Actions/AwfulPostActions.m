//
//  AwfulPostActions.m
//  Awful
//
//  Created by Regular Berry on 6/24/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostActions.h"
#import "AwfulPost.h"
#import "AwfulNavigator.h"
//#import "AwfulEditRequest.h"
//#import "AwfulQuoteRequest.h"
#import "AwfulPage.h"

typedef enum {
    AwfulPostActionTypeEdit,
    AwfulPostActionTypeQuote,
    AwfulPostActionTypeMarkRead,
} AwfulPostActionType;

@implementation AwfulPostActions

@synthesize post = _post;
@synthesize page = _page;

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
            /*AwfulEditContentRequest *edit = [[AwfulEditContentRequest alloc] initWithAwfulPost:self.post];
            loadRequest(edit);
            [self.navigator setActions:nil];*/
            return;
        }
    } else {
        action++;
    }
    
    if(action == AwfulPostActionTypeQuote) {
        
        /*AwfulQuoteRequest *quote = [[AwfulQuoteRequest alloc] initWithPost:self.post fromPage:self.page];
        loadRequest(quote);*/
        
    } else if(action == AwfulPostActionTypeMarkRead) {
        
        if(self.post.markSeenLink == nil) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not available" message:@"That feature requires you set 'Show an icon next to each post indicating if it has been seen or not' in your forum options" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        } else {
            /*NSURL *seen_url = [NSURL URLWithString:[@"http://forums.somethingawful.com/" stringByAppendingString:self.post.markSeenLink]];
            ASIHTTPRequest *seen_req = [ASIHTTPRequest requestWithURL:seen_url];
            seen_req.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Marked up to there.", @"completionMsg", nil];
            loadRequestAndWait(seen_req);*/
        }
    }
    
    //[self.navigator setActions:nil];
}

@end
