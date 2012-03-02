//
//  AwfulUser.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUser.h"
#import "AwfulLoginController.h"
//#import "AwfulUserInfoRequest.h"
#import "AwfulNavigator.h"
//#import "AwfulRequestHandler.h"
//#import "ASINetworkQueue.h"
#import "AwfulUtil.h"

@implementation AwfulUser

@synthesize userName, postsPerPage;

-(id)init
{
    if((self=[super init])) {
        self.postsPerPage = 40;
        [self loadUser];
    }
    return self;
}


-(void)loadUser
{
    // saved in UserInfo.plist
    NSString *path = [self getPath];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        [self setUserName:[dict objectForKey:@"userName"]];
        self.postsPerPage = [[dict objectForKey:@"postsPerPage"] intValue];
    } else {
        if(isLoggedIn()) {
            /*AwfulUserNameRequest *name_req = [[AwfulUserNameRequest alloc] initWithAwfulUser:self];
            AwfulUserSettingsRequest *settings_req = [[AwfulUserSettingsRequest alloc] initWithAwfulUser:self];
            
            AwfulNavigator *nav = getNavigator();
            [nav.requestHandler loadAllWithMessage:@"Loading Username..." forRequests:name_req, settings_req, nil];
             */
        }
    }
}

-(void)setUserName:(NSString *)user_name
{
    userName = user_name;
    [self saveUser];
}

-(void)setPostsPerPage:(int)in_posts
{
    postsPerPage = in_posts;
    [self saveUser];
}

-(NSString *)getPath
{
    return [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"awfulUser.plist"];
}

-(void)killUser
{
    self.userName = nil;
    NSError *err;
    BOOL woot = [[NSFileManager defaultManager] removeItemAtPath:[self getPath] error:&err];
    if(!woot) {
        NSLog(@"failed to kill %@", err);
    }
}

-(void)saveUser
{
    if(self.userName == nil) {
        return;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:self.userName, @"userName", 
        [NSNumber numberWithInt:self.postsPerPage], @"postsPerPage", nil];
    [dict writeToFile:[self getPath] atomically:YES];
}

@end
