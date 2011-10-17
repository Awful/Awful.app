//
//  AwfulNavigatorLabels.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulNavigatorLabels : UIViewController {
    UILabel *_pagesLabel;
    UILabel *_forumLabel;
    UILabel *_threadTitleLabel;
}

@property (nonatomic, retain) IBOutlet UILabel *pagesLabel;
@property (nonatomic, retain) IBOutlet UILabel *forumLabel;
@property (nonatomic, retain) IBOutlet UILabel *threadTitleLabel;

@end
