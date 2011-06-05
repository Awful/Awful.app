//
//  AwfulUser.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulUser.h"
#import "AwfulUserInfoRequest.h"
#import "AwfulNavController.h"
#import "AwfulUtil.h"

@implementation AwfulUser

@synthesize userName, postsPerPage;

-(id)init
{
    userName = nil;
    postsPerPage = 40;
    return self;
}

-(void)dealloc
{
    [userName release];
    [super dealloc];
}

-(void)loadUser
{
    // saved in UserInfo.plist
    NSString *path = [self getPath];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        [self setUserName:[dict objectForKey:@"userName"]];
        postsPerPage = [[dict objectForKey:@"postsPerPage"] intValue];
        //NSLog(@"Already Loaded: %@ %d", userName, postsPerPage);
    } else {
        AwfulUserNameRequest *name_req = [[AwfulUserNameRequest alloc] initWithAwfulUser:self];
        AwfulUserSettingsRequest *settings_req = [[AwfulUserSettingsRequest alloc] initWithAwfulUser:self];
        
        AwfulNavController *nav = getnav();
        [nav.queue addOperation:name_req];
        [nav.queue addOperation:settings_req];
        [nav.queue go];
        [name_req release];
        [settings_req release];
    }
}

-(void)setUserName:(NSString *)user_name
{
    if(user_name != userName) {
        [userName release];
        userName = [user_name retain];
        [self saveUser];
    }
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
    NSError *err;
    BOOL woot = [[NSFileManager defaultManager] removeItemAtPath:[self getPath] error:&err];
    if(!woot) {
        NSLog(@"failed to kill %@", err);
    }
}

-(void)saveUser
{
    if(userName == nil) {
        return;
    }
    
    //NSLog(@"%@ %d", userName, postsPerPage);
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:userName, @"userName", 
        [NSNumber numberWithInt:postsPerPage], @"postsPerPage", nil];
    [dict writeToFile:[self getPath] atomically:YES];
}

@end
