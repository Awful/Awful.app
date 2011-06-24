//
//  AwfulParse.h
//  Awful
//
//  Created by Sean Berry on 10/7/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulPageCount;
@class AwfulPost;
@class TFHpple;

@interface AwfulParse : NSObject {

}

+(NSString *)constructPageHTMLFromPosts : (NSMutableArray *)posts pagesLeft : (int)pages_left numOldPosts : (int)num_above;

+(NSMutableArray *)newPostsFromThread : (TFHpple *)hpple isFYAD : (BOOL)is_fyad;

+(NSString *)parseThumbnails : (NSString *)body_html;
+(NSString *)parseYouTubes : (NSString *)html;

+(NSMutableArray *)newThreadsFromForum : (TFHpple *)hpple;
+(NSString *)getAdHTMLFromData : (TFHpple *)hpple;

+(AwfulPageCount *)newPageCount : (TFHpple *)hpple;
+(int)getNewPostNumFromURL : (NSURL *)url;

@end
