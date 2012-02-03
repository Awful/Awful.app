//
//  AwfulPageTemplate.h
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulPost;

@interface AwfulPageTemplate : NSObject

@property (nonatomic, strong) NSString *mainHTML;
@property (nonatomic, strong) NSString *modImageHTML;
@property (nonatomic, strong) NSString *adminImageHTML;
@property (nonatomic, strong) NSString *postActionImageHTML;

-(NSString *)parseOutImages : (NSString *)html;
-(NSString *)parseEmbeddedVideos : (NSString *)html;
-(NSString *)constructHTMLForPost : (AwfulPost *)post;

@end
