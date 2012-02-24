//
//  AwfulPageDataController.h
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulForum;
@class AwfulPageCount;

@interface AwfulPageDataController : NSObject

@property (nonatomic, strong) NSString *threadTitle;
@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) AwfulPageCount *pageCount;
@property (nonatomic, strong) NSMutableArray *posts;
@property (nonatomic, assign) NSUInteger newestPostIndex;
@property (nonatomic, strong) NSString *userAd;

-(id)initWithResponseData : (NSData *)responseData pagePath : (NSString *)pagePath;
-(NSString *)constructedPageHTML;
-(NSString *)calculatePostIDScrollDestination;
-(BOOL)shouldScrollToBottom;

@end
