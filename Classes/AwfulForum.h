//
//  AwfulForum.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//



@interface AwfulForum : NSObject <NSCoding> {
    NSString *forumName;
    NSString *forumID;
}

@property (nonatomic, retain) NSString *forumName;
@property (nonatomic, retain) NSString *forumID;

-(id)initWithName : (NSString *)name forumid : (NSString *)forumid;

@end
