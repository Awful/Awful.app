//
//  AwfulForum.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForum.h"
#import "AwfulUtil.h"

@implementation AwfulForum

@synthesize forumID = _forumID;
@synthesize name = _name;
@synthesize parentForumID = _parentForumID;
@synthesize acronym = _acronym;

-(void)dealloc
{
    [_forumID release];
    [_name release];
    [_parentForumID release];
    [_acronym release];
    [super dealloc];
}

- (id)initWithCoder:(NSCoder *)decoder 
{
	if ((self=[super init])) {
		self.forumID = [decoder decodeObjectForKey:@"forumID"];
        self.name = [decoder decodeObjectForKey:@"name"];
        self.parentForumID = [decoder decodeObjectForKey:@"parentForumID"];
        self.acronym = [decoder decodeObjectForKey:@"acronym"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.forumID forKey:@"forumID"];
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.parentForumID forKey:@"parentForumID"];
    [encoder encodeObject:self.acronym forKey:@"acronym"];
}

+(id)awfulForumFromID : (NSString *)forum_id
{
    NSMutableArray *forums = [AwfulForum getForumsList];
    AwfulForum *found_forum = nil;
    for(AwfulForum *forum in forums) {
        if([forum.forumID isEqualToString:forum_id]) {
            found_forum = forum;
        }
    }
    
    if(found_forum != nil) {
        return [[found_forum retain] autorelease];
    }
    return nil;
}

+(NSMutableArray *)getForumsList
{
    NSString *path = [[AwfulUtil getDocsDir] stringByAppendingPathComponent:@"forumslist"];
    NSMutableArray *forums = nil;
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        forums = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    } 
    
    if(forums == nil || [forums count] == 0) {
        NSString *bundle_path = [[NSBundle mainBundle] pathForResource:@"forumslist" ofType:@""];
        forums = [NSKeyedUnarchiver unarchiveObjectWithFile:bundle_path];
    }
    return forums;
}

@end
