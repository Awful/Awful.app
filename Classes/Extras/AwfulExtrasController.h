//
//  AwfulExtrasController.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulLabelCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *label;

@end

@interface AwfulButtonCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIButton *button;
@property (nonatomic, weak) id buttonTarget;

-(void)setSelector : (SEL)selector withText : (NSString *)text;

@end

@interface AwfulExtrasController : UITableViewController

@property (nonatomic, strong) IBOutlet AwfulButtonCell *buttonCell;
@property (nonatomic, strong) IBOutlet AwfulLabelCell *labelCell;

-(NSIndexPath *)getIndexPathForLoggedInCell;
-(NSString *)cellIdentifierForIndexPath : (NSIndexPath *)indexPath;
-(void)tappedLogin;
-(void)tappedLogout;
-(void)tappediCloudRefresh;
-(void)tappedHelp;
-(void)tappedAwfulAppThread;
-(void)reloadUserName;

@end

@interface AwfulExtrasControllerIpad : AwfulExtrasController
@end