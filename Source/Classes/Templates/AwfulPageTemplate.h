//
//  AwfulPageTemplate.h
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulPageDataController;
@class AwfulForum;

@interface AwfulPageTemplate : NSObject


-(NSURL *)getTemplateURLFromForum : (AwfulForum *)forum;
- (NSString *)renderWithPageDataController:(AwfulPageDataController *)dataController;
- (NSString *)renderWithPageDataController:(AwfulPageDataController *)dataController displayAllPosts : (BOOL)displayAllPosts;

@end
