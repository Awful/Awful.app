//
//  AwfulPageNavController.h
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;

@interface AwfulPageNavController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource> {
    UIBarButtonItem *_pageLabel;
    UIPickerView *_picker;
    AwfulPage *_page;
    UIToolbar *_toolbar;
}

-(id)initWithAwfulPage : (AwfulPage *)page;

@property (nonatomic, retain) AwfulPage *page;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *pageLabel;
@property (nonatomic, retain) IBOutlet UIPickerView *picker;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;

-(IBAction)go;
-(IBAction)cancel;

@end
