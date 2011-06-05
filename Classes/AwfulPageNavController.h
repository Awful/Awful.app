//
//  AwfulPageNavController.h
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulPage.h"
#import "AwfulForum.h"

@interface AwfulPageNavController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource> {
    UIButton *cancelButton;
    UIButton *goButton;
    UILabel *pageLabel;
    
    UIPickerView *picker;
    
    AwfulPage *page;
}

-(id)initWithAwfulPage : (AwfulPage *)in_page;

@property (nonatomic, retain) IBOutlet UIButton *cancelButton;
@property (nonatomic, retain) IBOutlet UIButton *goButton;
@property (nonatomic, retain) IBOutlet UILabel *pageLabel;
@property (nonatomic, retain) IBOutlet UIPickerView *picker;

-(IBAction)go;
-(IBAction)cancel;

@end
