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

@interface AwfulThreadCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *threadTitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *pagesLabel;
@property (nonatomic, strong) IBOutlet UIButton *unreadButton;
@property (nonatomic, strong) IBOutlet UIImageView *sticky;
@property (nonatomic, strong) AwfulThread *thread;

-(void)configureForThread : (AwfulThread *)aThread;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)aThread;
-(void)openThreadlistOptions;

@end
