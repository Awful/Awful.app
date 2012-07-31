//
//  AwfulTableViewCellEmoticonMultiple.h
//  Awful
//
//  Created by me on 4/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class FVGifAnimation;
@interface AwfulTableViewCellEmoticonMultiple : UITableViewCell {
    NSMutableArray *_emoteViews;
    FVGifAnimation __strong *animation;
}

@property (nonatomic) BOOL showCodes;

-(void) setContent:(NSArray*)emotes;
@end
