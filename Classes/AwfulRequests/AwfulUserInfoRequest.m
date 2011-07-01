//
//  AwfulUserInfoRequest.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUserInfoRequest.h"
#import "TFHpple.h"
#import "AwfulNavigator.h"
#import "AwfulExtrasController.h"

@implementation AwfulUserNameRequest

@synthesize user = _user;

-(id)initWithAwfulUser : (AwfulUser *)user
{
    if((self = [super initWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/index.php"]])) {
        _user = [user retain];
    }
    
    return self;
}

-(void)dealloc
{
    [_user release];
    [super dealloc];
}

-(void)requestFinished
{
    [super requestFinished];
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:[self responseData]];
    TFHppleElement *name_el = [page_data searchForSingle:@"//div[@class='mainbodytextsmall']/b"];
    if(name_el != nil) {
        [self.user setUserName:name_el.content];
        
        AwfulNavigator *nav = getNavigator();
        if([[nav.navigationController visibleViewController] isMemberOfClass:[AwfulExtrasController class]]) {
            AwfulExtrasController *extras = (AwfulExtrasController *)nav.navigationController.visibleViewController;
            [extras reloadUserName];
        }
    }
    [page_data release];
}

@end


@implementation AwfulUserSettingsRequest

-(id)initWithAwfulUser : (AwfulUser *)user
{    
    if((self = [super initWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/member.php?action=editoptions"]])) {
        _user = [user retain];
    }
    
    return self;
}

-(void)requestFinished
{
    [super requestFinished];
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:[self responseData]];
    NSArray *options_el = [page_data search:@"//select[@name='umaxposts']//option"];
    
    for(TFHppleElement *el in options_el) {
        if([el objectForKey:@"selected"] != nil) {
            NSString *val = [el objectForKey:@"value"];
            [self.user setPostsPerPage:[val intValue]];
        }
    }
    
    [page_data release];
}

@end

