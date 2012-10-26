//
//  AwfulPageTemplate.h
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class PageParsedInfo;

@interface AwfulPageTemplate : NSObject

- (NSString *)renderWithPageInfo:(PageParsedInfo *)pageInfo displayAllPosts:(BOOL)displayAllPosts;

@end
