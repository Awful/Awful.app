//
//  AwfulThreadCell.h
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "TDBadgedCell.h"

@class AwfulThread;
@class AwfulThreadListController;

@interface AwfulThreadCell : TDBadgedCell

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) IBOutlet UILabel *threadTitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *pagesLabel;
@property (nonatomic, strong) IBOutlet UIButton *unreadButton;
@property (nonatomic, strong) IBOutlet UIImageView *sticky;
@property (nonatomic, strong) IBOutlet UIImageView *tagImage;
@property (nonatomic, strong) IBOutlet UIImageView *secondTagImage;
@property (nonatomic, strong) IBOutlet UIImageView *ratingImage;
@property (nonatomic, weak) AwfulThreadListController *threadListController;
@property (nonatomic, strong) IBOutlet UILabel *tagLabel;
@property (nonatomic, strong) IBOutlet UIView *tagContainerView;

+(UIColor*) textColor;
+(UIColor*) backgroundColor;
+(UIFont*) textLabelFont;
+(UIFont*) detailLabelFont;

-(void)configureForThread : (AwfulThread *)thread;
-(void) configureTagImage;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread;
-(void)openThreadlistOptions : (UIGestureRecognizer *)gesture;


-(void) willLoadThreadPage:(NSNotification*)notification;
-(void) didLoadThreadPage:(NSNotification*)notification;

+(CGFloat) heightForContent:(AwfulForum*)forum inTableView:(UITableView*)tableView;
@end

