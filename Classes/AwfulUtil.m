//
//  AwfulUtil.m
//  Awful
//
//  Created by Sean Berry on 7/30/10.
//  Copyright 2010 Regular Berry Software LLC.
//
/* Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "AwfulUtil.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavigator.h"
#import "AwfulUser.h"

@implementation AwfulUtil

+(NSString *)getDocsDir
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+(FMDatabase *)getDB
{
    return [FMDatabase databaseWithPath:[[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"forums.sqlite"]];
}

+(void)initializeDatabase
{
    NSFileManager *me = [[NSFileManager alloc] init];
    NSString *db_path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"forums.sqlite"];
    BOOL success = [me fileExistsAtPath:db_path];
    if(!success) {
        NSString *current_db_path = [[NSBundle mainBundle] pathForResource:@"forums" ofType:@"sqlite"];
        
        NSError *err = nil;
        success = [me copyItemAtPath:current_db_path toPath:db_path error:&err];
        if(!success) {
            NSLog(@"failed to copy db");
        }
    }
    
    [me release];
}

+(NSMutableArray *)newChosenForums
{
    NSString *forums_path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"chosenForums"];
    if([[NSFileManager defaultManager] fileExistsAtPath:forums_path]) {
        NSMutableArray *forums = [NSKeyedUnarchiver unarchiveObjectWithFile:forums_path];
        [forums retain];
        return forums;
    } else {
        NSMutableArray *empty = [[NSMutableArray alloc] init];
        return empty;
    }
    return nil;
}

+(void)saveChosenForums : (NSMutableArray *)forums
{
    NSString *forums_path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"chosenForums"];
    BOOL saved = [NSKeyedArchiver archiveRootObject:forums toFile:forums_path];
    if(!saved) {
        NSLog(@"failed to save");
    }
}

+(NSMutableArray *)newThreadListForForumId : (NSString *)forum_id
{
    NSString *path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:forum_id];
    
    NSMutableArray *threads = [[NSMutableArray alloc] init];;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSArray *t = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        [threads addObjectsFromArray:t];
    }
    
    return threads;
}

+(void)saveThreadList : (NSMutableArray *)list forForumId : (NSString *)forum_id
{
    NSString *path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:forum_id];
    BOOL result = [NSKeyedArchiver archiveRootObject:list toFile:path];
    if(!result) {
        NSLog(@"failed to save threadlist");
    }
}

@end

int getPostsPerPage()
{
    AwfulNavigator *nav = getNavigator();
    AwfulUser *user = nav.user;
    if(user == nil) {
        return 40;
    }
    return user.postsPerPage;
}

NSString *getUsername()
{
    AwfulNavigator *nav = getNavigator();
    AwfulUser *user = nav.user;
    return [user userName];
}
