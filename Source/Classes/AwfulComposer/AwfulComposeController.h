//
//  AwfulComposeController.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AwfulPostComposerView;
@class AwfulDraft;

@interface AwfulComposeController : UITableViewController {
    @protected NSArray *_cells;
}
@property (nonatomic,strong) NSArray* cells;
@property (nonatomic,strong) AwfulPostComposerView* composerView;
@property (nonatomic,readonly) NSString* submitString;
@property (nonatomic,strong) AwfulDraft* draft;
@end
