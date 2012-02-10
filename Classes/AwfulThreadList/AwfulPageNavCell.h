//
//  AwfulPageNavCell.h
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class AwfulPageCount;

@interface AwfulPageNavCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIButton *nextButton;
@property (nonatomic, strong) IBOutlet UIButton *prevButton;
@property (nonatomic, strong) IBOutlet UILabel *pageLabel;

-(void)configureForPageCount : (AwfulPageCount *)pages thread_count : (int)count;

@end