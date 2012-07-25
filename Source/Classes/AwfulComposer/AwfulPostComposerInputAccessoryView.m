//
//  AwfulPostComposerInputAccessoryView.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerInputAccessoryView.h"
#import "AwfulEmoteChooser.h"
#import "UIBarButtonItem+Lazy.h"

@implementation AwfulPostComposerInputAccessoryView
@synthesize formattingControl = _formattingControl;
@synthesize insertionControl = _insertionControl;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor greenColor];
        
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:self.frame];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _formattingControl = [[UISegmentedControl alloc] initWithItems:
                                   [NSArray arrayWithObjects:@"B",@"I",@"U",/*@"S",@"Sup",@"Sub",*/ nil]
                                   ];
        self.formattingControl.segmentedControlStyle = UISegmentedControlStyleBar;
        [self.formattingControl addTarget:self action:@selector(formattingControlChanged:) forControlEvents:UIControlEventValueChanged];
        
        _insertionControl = [[UISegmentedControl alloc] initWithItems:
                             [NSArray arrayWithObjects:@"+Img", [UIImage imageNamed:@"emot-v.gif"], nil]
                             ];
        self.insertionControl.segmentedControlStyle = UISegmentedControlStyleBar;
        [self.insertionControl addTarget:self action:@selector(insertControlChanged:) forControlEvents:UIControlEventValueChanged];
         
        
        toolbar.items = [NSArray arrayWithObjects:
                         [[UIBarButtonItem alloc] initWithCustomView:self.formattingControl],
                         [UIBarButtonItem flexibleSpace],
                         [[UIBarButtonItem alloc] initWithCustomView:self.insertionControl],
                          nil
                          ];
        [self addSubview:toolbar];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(didChooseEmoticon:) 
                                                     name:AwfulEmoteChosenNotification 
                                                   object:nil
         ];
        
    }
    return self;
}

-(void) insertControlChanged:(UISegmentedControl*)segmentedControl {
    if (segmentedControl.selectedSegmentIndex == 1) {
        AwfulEmoteChooser *chooser = [AwfulEmoteChooser new];
        pop = [[UIPopoverController alloc] initWithContentViewController:chooser];
        [pop setPopoverContentSize:CGSizeMake(125*4, 768)];
        [pop presentPopoverFromRect:segmentedControl.frame inView:self permittedArrowDirections:(UIPopoverArrowDirectionDown) animated:YES];
    }
    else if (segmentedControl.selectedSegmentIndex == 0) {
        UIImagePickerController *picker = [UIImagePickerController new];
        pop = [[UIPopoverController alloc] initWithContentViewController:picker];
        [pop setPopoverContentSize:CGSizeMake(320, 768)];  
    }
    
    CGFloat width = segmentedControl.fsW/segmentedControl.numberOfSegments;
    CGRect frame = CGRectMake(segmentedControl.foX+width*segmentedControl.selectedSegmentIndex, 0, width, segmentedControl.fsH);
    
    [pop presentPopoverFromRect:frame inView:self permittedArrowDirections:(UIPopoverArrowDirectionDown) animated:YES];
    
}

-(void) formattingControlChanged:(UISegmentedControl*)segmentedControl {
    NSLog(@"tapped %i", segmentedControl.selectedSegmentIndex);
    [self sendActionsForControlEvents:AwfulPostComposerInputAccessoryEventFormat];
}

-(void) didChooseEmoticon:(NSNotification*)notification {
    self.insertionControl.selectedSegmentIndex = -1;
    [pop dismissPopoverAnimated:YES];
}

-(AwfulPostFormatStyle) formatState {
    return self.formattingControl.selectedSegmentIndex;
}



@end
