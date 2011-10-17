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
    UIBarButtonItem *_barTitle;
    UIButton *_forumButton;
    UITextField *_pageTextField;
    AwfulPage *_page;
    UIToolbar *_toolbar;
    
    UIButton *_nextButton;
    UIButton *_prevButton;
    UIButton *_firstButton;
    UIButton *_lastButton;
}

-(id)initWithAwfulPage : (AwfulPage *)page;

@property (nonatomic, retain) AwfulPage *page;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *barTitle;
@property (nonatomic, retain) IBOutlet UIButton *forumButton;
@property (nonatomic, retain) IBOutlet UITextField *pageTextField;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;

@property (nonatomic, retain) IBOutlet UIButton *nextButton;
@property (nonatomic, retain) IBOutlet UIButton *prevButton;
@property (nonatomic, retain) IBOutlet UIButton *firstButton;
@property (nonatomic, retain) IBOutlet UIButton *lastButton;

-(IBAction)hitGo : (id)sender;
-(IBAction)hitCancel : (id)sender;
-(IBAction)hitNext : (id)sender;
-(IBAction)hitPrev : (id)sender;
-(IBAction)hitFirst : (id)sender;
-(IBAction)hitLast : (id)sender;
-(IBAction)hitForum : (id)sender;
-(IBAction)tappedOutside : (UITapGestureRecognizer *)tap;

@end
