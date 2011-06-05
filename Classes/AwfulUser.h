//
//  AwfulUser.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AwfulUser : NSObject {
    int postsPerPage;
    NSString *userName;
}

@property (nonatomic, retain) NSString *userName;
@property (nonatomic, assign) int postsPerPage;

-(void)loadUser;
-(void)saveUser;
-(void)killUser;
-(NSString *)getPath;

@end
