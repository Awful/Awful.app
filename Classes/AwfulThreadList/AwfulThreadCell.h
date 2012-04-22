//
//  AwfulThreadCell.h
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class AwfulThread;
@class AwfulThreadListController;

@interface AwfulThreadCell : UITableViewCell

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) IBOutlet UILabel *threadTitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *pagesLabel;
@property (nonatomic, strong) IBOutlet UIButton *unreadButton;
@property (nonatomic, strong) IBOutlet UIImageView *sticky;
@property (nonatomic, strong) IBOutlet UIImageView *tagImage;
@property (nonatomic, strong) IBOutlet UIImageView *secondTagImage;
@property (nonatomic, strong) IBOutlet UIImageView *ratingImage;
@property (nonatomic, weak) AwfulThreadListController *threadListController;

-(void)configureForThread : (AwfulThread *)thread;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread;
-(void)openThreadlistOptions : (UIGestureRecognizer *)gesture;

@end
