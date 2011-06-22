//
//  AwfulExtrasController.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulLabelCell : UITableViewCell {
    UILabel *_label;
}

@property (nonatomic, retain) IBOutlet UILabel *label;

@end

@interface AwfulButtonCell : UITableViewCell {
    UIButton *_button;
    id _buttonTarget;
}

-(void)setSelector : (SEL)selector withText : (NSString *)text;

@property (nonatomic, retain) IBOutlet UIButton *button;
@property (nonatomic, assign) id buttonTarget;

@end

@interface AwfulExtrasController : UITableViewController {
    AwfulButtonCell *_buttonCell;
    AwfulLabelCell *_userInfoCell;
}

@property (nonatomic, retain) IBOutlet AwfulButtonCell *buttonCell;
@property (nonatomic, retain) IBOutlet AwfulLabelCell *labelCell;

-(NSIndexPath *)getIndexPathForLoggedInCell;
-(NSString *)cellIdentifierForIndexPath : (NSIndexPath *)indexPath;
-(void)tappedLogin;
-(void)tappedLogout;

@end
