//
//  AwfulSmallPageController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;

@interface AwfulSmallPageController : UIViewController {
    AwfulPage *_page;
    UISegmentedControl *_segment;
    BOOL _hiding;
    BOOL _submitting;
}

@property (nonatomic, retain) AwfulPage *page;
@property (nonatomic, retain) IBOutlet UISegmentedControl *segment;
@property BOOL hiding;
@property BOOL submitting;

-(id)initWithAwfulPage : (AwfulPage *)page;

-(IBAction)selected : (UISegmentedControl *)sender;
-(IBAction)hitNext;
-(IBAction)hitPrev;
-(IBAction)hitFirst;
-(IBAction)hitLast;

@end
