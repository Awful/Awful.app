//
//  AwfulConfig.h
//  Awful
//
//  Created by Sean Berry on 1/1/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface AwfulConfig : UIView {

}

+(id)getConfigObj : (NSString *)key;
+(BOOL)showAvatars;
+(float)bookmarksDelay;
+(int)numReadPostsAbove;

@end
