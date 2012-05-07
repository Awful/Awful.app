//
//  AwfulTableViewCellEmoticonMultiple.h
//  Awful
//
//  Created by me on 4/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulTableViewCellEmoticonMultiple : UITableViewCell {
    NSMutableArray *_emoteViews;
}

-(void) setContent:(NSArray*)emotes;
@end
