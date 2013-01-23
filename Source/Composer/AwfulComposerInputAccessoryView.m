//
//  AwfulPostComposerInputAccessoryView.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerInputAccessoryView.h"
//#import "AwfulEmotePickerController.h"
//#import "UIBarButtonItem+Lazy.h"

@implementation AwfulComposerInputAccessoryView
@synthesize formattingControl = _formattingControl;
@synthesize insertionControl = _insertionControl;
@synthesize extraKeysControl = _extraKeysControl;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor greenColor];
        
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:self.frame];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        toolbar.tintColor = [UIColor colorWithRed:.61 green:.61 blue:.65 alpha:1];

                

         
        
        toolbar.items = @[
            [[UIBarButtonItem alloc] initWithCustomView:self.formattingControl],
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace) target:nil action:nil],
            [[UIBarButtonItem alloc] initWithCustomView:self.insertionControl],
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace) target:nil action:nil],
            [[UIBarButtonItem alloc] initWithCustomView:self.extraKeysControl]
        ];
        [self addSubview:toolbar];
        
//        [[NSNotificationCenter defaultCenter] addObserver:self 
//                                                 selector:@selector(didChooseEmoticon:) 
//                                                     name:AwfulEmoteChosenNotification 
//                                                   object:nil
//         ];
        
    }
    return self;
}

- (UISegmentedControl*)formattingControl {
    if (_formattingControl) return _formattingControl;
    _formattingControl = [[UISegmentedControl alloc] initWithItems:
                          @[@"B",@"I",@"U"/*@,"S",@"Sup",@"Sub",*/]
                          ];
    _formattingControl.segmentedControlStyle = UISegmentedControlStyleBar;
    [_formattingControl addTarget:self
                           action:@selector(formattingControlChanged:)
                 forControlEvents:UIControlEventValueChanged];
    _formattingControl.tintColor = [UIColor colorWithRed:.88 green:.88 blue:.89 alpha:1];
    [_formattingControl setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor blackColor],
                UITextAttributeTextShadowColor:[UIColor clearColor]}
                                      forState:UIControlStateNormal];
    return _formattingControl;
}

- (UISegmentedControl*)insertionControl {
    if (_insertionControl) return _insertionControl;
    _insertionControl = [[UISegmentedControl alloc] initWithItems:
                         @[@"+Img", [UIImage imageNamed:@"emot-v.gif"]]
                         ];
    _insertionControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _insertionControl.tintColor = [UIColor colorWithRed:.88 green:.88 blue:.89 alpha:1];
    [_insertionControl setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor blackColor],
               UITextAttributeTextShadowColor:[UIColor clearColor]}
                                      forState:UIControlStateNormal];
    [_insertionControl addTarget:self
                              action:@selector(insertControlChanged:)
                    forControlEvents:UIControlEventValueChanged];
    return _insertionControl;
}

- (UISegmentedControl*)extraKeysControl {
    if (_extraKeysControl) return _extraKeysControl;
    _extraKeysControl = [[UISegmentedControl alloc] initWithItems:
                         @[@"[", @"]", @"/", @"=", @":"]
                         ];
    _extraKeysControl.segmentedControlStyle = UISegmentedControlStyleBar;
    _extraKeysControl.momentary = YES;
    _extraKeysControl.tintColor = [UIColor colorWithRed:.88 green:.88 blue:.89 alpha:1];
    [_extraKeysControl setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor blackColor],
               UITextAttributeTextShadowColor:[UIColor clearColor]}
                                      forState:UIControlStateNormal];
    [_extraKeysControl addTarget:self
                              action:@selector(extraKeysControlChanged:)
                    forControlEvents:UIControlEventValueChanged];
    return _extraKeysControl;
}


//-(void) insertControlChanged:(UISegmentedControl*)segmentedControl {
//    if (segmentedControl.selectedSegmentIndex == 1) {
//        AwfulEmotePickerController *chooser = [AwfulEmotePickerController new];
//        pop = [[UIPopoverController alloc] initWithContentViewController:chooser];
//        [pop setPopoverContentSize:CGSizeMake(125*4, 768)];
//        [pop presentPopoverFromRect:segmentedControl.frame inView:self permittedArrowDirections:(UIPopoverArrowDirectionDown) animated:YES];
//    }
//    else if (segmentedControl.selectedSegmentIndex == 0) {
//        UIImagePickerController *picker = [UIImagePickerController new];
//        pop = [[UIPopoverController alloc] initWithContentViewController:picker];
//        [pop setPopoverContentSize:CGSizeMake(320, 768)];  
//    }
//    
//    CGFloat width = segmentedControl.fsW/segmentedControl.numberOfSegments;
//    CGRect frame = CGRectMake(segmentedControl.foX+width*segmentedControl.selectedSegmentIndex, 0, width, segmentedControl.fsH);
//    
//    [pop presentPopoverFromRect:frame inView:self permittedArrowDirections:(UIPopoverArrowDirectionDown) animated:YES];
//    
//}

-(void) formattingControlChanged:(UISegmentedControl*)segmentedControl {
    NSLog(@"tapped %i", segmentedControl.selectedSegmentIndex);
    [self sendActionsForControlEvents:AwfulControlEventComposerFormat];
}

-(void) extraKeysControlChanged:(UISegmentedControl*)segmentedControl {
    NSLog(@"tapped %i", segmentedControl.selectedSegmentIndex);
    [self sendActionsForControlEvents:AwfulControlEventComposerKey];
}

//-(void) didChooseEmoticon:(NSNotification*)notification {
//    self.insertionControl.selectedSegmentIndex = -1;
//    [pop dismissPopoverAnimated:YES];
//}

-(AwfulPostFormatStyle) formatState {
    return self.formattingControl.selectedSegmentIndex;
}



@end
