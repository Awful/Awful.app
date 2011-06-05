//
//  AwfulParse.h
//  Awful
//
//  Created by Sean Berry on 10/7/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPost.h"
#import "TFHpple.h"

@interface AwfulParse : NSObject {

}

+(NSString *)constructPostHTML : (AwfulPost *)post alt : (NSString *)alt;

+(NSMutableArray *)newPostsFromThread : (TFHpple *)hpple isFYAD : (BOOL)is_fyad;

+(NSString *)parseThumbnails : (NSString *)body_html;
+(NSString *)parseYouTubes : (NSString *)html;

+(NSMutableArray *)newThreadsFromForum : (TFHpple *)hpple;
+(NSString *)getAdHTMLFromData : (TFHpple *)hpple;

+(PageManager *)newPageManager : (TFHpple *)hpple;
+(int)getNewPostNumFromURL : (NSURL *)url;

@end
