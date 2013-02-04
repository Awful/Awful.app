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
#import "AwfulEmoticonChooserViewController.h"

@implementation AwfulComposerInputAccessoryView
@synthesize formattingControl = _formattingControl;
@synthesize insertionControl = _insertionControl;
@synthesize extraKeysControl = _extraKeysControl;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor greenColor];
        
        _toolbar = [[UIToolbar alloc] initWithFrame:self.frame];
        _toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _toolbar.tintColor = [UIColor colorWithRed:.61 green:.61 blue:.65 alpha:1];

                

         
        
        _toolbar.items = @[
            [[UIBarButtonItem alloc] initWithCustomView:self.formattingControl],
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace) target:nil action:nil],
            [[UIBarButtonItem alloc] initWithCustomView:self.insertionControl],
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace) target:nil action:nil],
            [[UIBarButtonItem alloc] initWithCustomView:self.extraKeysControl]
        ];
        [self addSubview:_toolbar];
        
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
                          @[@"B",@"I",@"U", @"S", @"Spoil",@"Sub",@"Super"]
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
                              action:@selector(insertionControlChanged:)
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
    
    for(uint i=0;i<_extraKeysControl.numberOfSegments;i++) {
        [_extraKeysControl setWidth:44 forSegmentAtIndex:i];
    }
    return _extraKeysControl;
}


- (void)insertionControlChanged:(UISegmentedControl*)segmentedControl {
    if (segmentedControl.selectedSegmentIndex == 0)
        [self.delegate insertImage:segmentedControl.selectedSegmentIndex];
    else
        [self showEmoticonChooser];
}

- (void)formattingControlChanged:(UISegmentedControl*)segmentedControl {
    [self.delegate setFormat:segmentedControl.selectedSegmentIndex];
}

- (void)extraKeysControlChanged:(UISegmentedControl*)segmentedControl {
    [self.delegate insertString:[segmentedControl titleForSegmentAtIndex:segmentedControl.selectedSegmentIndex]];
}

- (void)showEmoticonChooser {
    [self.delegate showEmoticonChooser];
    /*
    AwfulEmoticonKeyboardController* chooser = [AwfulEmoticonKeyboardController new];
    chooser.delegate = self.delegate;
    
    pop = [[UIPopoverController alloc] initWithContentViewController:chooser];
    [pop presentPopoverFromRect:self.insertionControl.frame
                         inView:self.toolbar
                permittedArrowDirections:(UIPopoverArrowDirectionDown)
                                animated:YES];
     */
}

-(AwfulPostFormatStyle) formatState {
    return self.formattingControl.selectedSegmentIndex;
}



@end
