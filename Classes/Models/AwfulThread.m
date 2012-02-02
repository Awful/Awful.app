//
//  AwfulThread.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"
#import "AwfulForum.h"
#import "TFHpple.h"
#import "XPathQuery.h"

@implementation AwfulThread

@synthesize threadID, title;
@synthesize totalUnreadPosts, totalReplies, threadRating;
@synthesize starCategory, threadIconImageURL, authorName, lastPostAuthorName;
@synthesize seen, isStickied, isLocked, forum;

-(id)init
{
    if((self=[super init])) {
        self.threadRating = NSNotFound;
        self.starCategory = AwfulStarCategoryNone;
        self.seen = NO;
        self.isStickied = NO;
        self.isLocked = NO;
        self.totalUnreadPosts = -1;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder 
{
	if ((self=[super init])) {
		self.threadID = [decoder decodeObjectForKey:@"threadID"];
		self.title = [decoder decodeObjectForKey:@"title"];
        if(self.title == nil) {
            self.title = @"";
        }
        self.totalUnreadPosts = [decoder decodeIntForKey:@"totalUnreadPosts"];
        self.totalReplies = [decoder decodeIntForKey:@"totalReplies"];
        self.threadRating = [decoder decodeIntForKey:@"threadRating"];
        self.starCategory = [decoder decodeIntForKey:@"starCategory"];
        
		self.threadIconImageURL = [decoder decodeObjectForKey:@"threadIconImageURL"];
        self.authorName = [decoder decodeObjectForKey:@"authorName"];
        self.lastPostAuthorName = [decoder decodeObjectForKey:@"lastPostAuthorName"];
        
        self.seen = [decoder decodeBoolForKey:@"seen"];
        self.isStickied = [decoder decodeBoolForKey:@"isStickied"];
        self.isLocked = [decoder decodeBoolForKey:@"isLocked"];
        self.forum = [decoder decodeObjectForKey:@"forum"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.threadID forKey:@"threadID"];
    [encoder encodeObject:self.title forKey:@"title"];
    [encoder encodeInt:self.totalUnreadPosts forKey:@"totalUnreadPosts"];
    [encoder encodeInt:self.totalReplies forKey:@"totalReplies"];
    [encoder encodeInt:self.threadRating forKey:@"threadRating"];
    [encoder encodeInt:self.starCategory forKey:@"starCategory"];
    
    [encoder encodeObject:self.threadIconImageURL forKey:@"threadIconImageURL"];
    [encoder encodeObject:self.authorName forKey:@"authorName"];
    [encoder encodeObject:self.lastPostAuthorName forKey:@"lastPostAuthorName"];
    
    [encoder encodeBool:self.seen forKey:@"seen"];
    [encoder encodeBool:self.isStickied forKey:@"isStickied"];
    [encoder encodeBool:self.isLocked forKey:@"isLocked"];
    
    [encoder encodeObject:self.forum forKey:@"forum"];
}


@end
