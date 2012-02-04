//
//  AwfulPageTemplate.h
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulPost;
@class AwfulPageDataController;

@interface AwfulPageTemplate : NSObject

@property (nonatomic, strong) NSString *mainHTML;
@property (nonatomic, strong) NSString *postHTML;
@property (nonatomic, strong) NSString *avatarHTML;
@property (nonatomic, strong) NSString *modImageHTML;
@property (nonatomic, strong) NSString *adminImageHTML;
@property (nonatomic, strong) NSString *postActionImageHTML;
@property (nonatomic, strong) NSString *pageCSS;

-(NSString *)parseOutImages : (NSString *)html;
-(NSString *)parseEmbeddedVideos : (NSString *)html;
-(NSString *)constructHTMLForPost : (AwfulPost *)post;
-(NSString *)constructHTMLFromPageDataController : (AwfulPageDataController *)dataController;

@end
