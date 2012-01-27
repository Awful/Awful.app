//
//  AwfulConfig.h
//  Awful
//
//  Created by Sean Berry on 1/1/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    AwfulDefaultLoadTypeNone,
    AwfulDefaultLoadTypeBookmarks,
    AwfulDefaultLoadTypeForums
} AwfulDefaultLoadType;


@interface AwfulConfig : UIView {

}

+(id)getConfigObj : (NSString *)key;
+(BOOL)showAvatars;
+(BOOL)showImages;
+(float)bookmarksDelay;
+(float)forumsDelay;
+(int)numReadPostsAbove;
+(AwfulDefaultLoadType)getDefaultLoadType;
+(NSString *)highlightOwnQuotes;
+(NSString *)highlightOwnMentions;

@end
