//
//  AwfulUserInfoRequest.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUserInfoRequest.h"
#import "TFHpple.h"

@implementation AwfulUserNameRequest

@synthesize user;

-(id)initWithAwfulUser : (AwfulUser *)in_user
{
    [self setUser:in_user];
    
    self = [super initWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/index.php"]];
    
    return self;
}

-(void)dealloc
{
    [user release];
    [super dealloc];
}

-(void)requestFinished
{
    [super requestFinished];
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:[self responseData]];
    TFHppleElement *name_el = [page_data searchForSingle:@"//div[@class='mainbodytextsmall']/b"];
    if(name_el != nil) {
        [user setUserName:name_el.content];
    }
    [page_data release];
}

@end


@implementation AwfulUserSettingsRequest

-(id)initWithAwfulUser : (AwfulUser *)in_user
{
    [self setUser:in_user];
    
    self = [super initWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/member.php?action=editoptions"]];
    
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
            [user setPostsPerPage:[val intValue]];
        }
    }
    
    [page_data release];
}

@end

