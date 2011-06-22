//
//  AwfulUser.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUser.h"
#import "AwfulLoginController.h"
#import "AwfulUserInfoRequest.h"
#import "AwfulNavigator.h"
#import "AwfulRequestHandler.h"
#import "ASINetworkQueue.h"
#import "AwfulUtil.h"

@implementation AwfulUser

@synthesize userName = _userName;
@synthesize postsPerPage = _postsPerPage;

-(id)init
{
    _postsPerPage = 40;
    return self;
}

-(void)dealloc
{
    [_userName release];
    [super dealloc];
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
            AwfulUserNameRequest *name_req = [[AwfulUserNameRequest alloc] initWithAwfulUser:self];
            AwfulUserSettingsRequest *settings_req = [[AwfulUserSettingsRequest alloc] initWithAwfulUser:self];
            
            AwfulNavigator *nav = getNavigator();
            [nav.requestHandler loadAllWithMessage:@"Loading Username..." forRequests:name_req, settings_req, nil];
            //[nav.requestHandler.queue addOperation:name_req];
            //loadRequestAndWait(settings_req);
            //[nav.requestHandler.queue addOperation:settings_req];
            //[nav.requestHandler.queue go];
            [name_req release];
            [settings_req release];
        }
    }
}

-(void)setUserName:(NSString *)user_name
{
    if(user_name != _userName) {
        [_userName release];
        _userName = [user_name retain];
        [self saveUser];
    }
}

-(void)setPostsPerPage:(int)in_posts
{
    _postsPerPage = in_posts;
    [self saveUser];
}

-(NSString *)getPath
{
    return [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"awfulUser.plist"];
}

-(void)killUser
{
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
