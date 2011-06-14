//
//  AwfulForum.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForum.h"

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

@end
