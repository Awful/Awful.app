//
//  AwfulPostComposerInputAccessoryView.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerInputAccessoryView.h"
#import "AwfulEmoteChooser.h"

@implementation AwfulPostComposerInputAccessoryView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor greenColor];
        
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:self.frame];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:
                                   [NSArray arrayWithObjects:@"Bold",@"Italic",@"Underline",@"Strike",@"Super",@"Sub",@"Insert Image", nil]
                                   ];
        seg.segmentedControlStyle = UISegmentedControlStyleBar;
        seg.momentary = YES;
        
        UIButton *addEmoteButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [addEmoteButton setImage:[UIImage imageNamed:@"emot-v.gif"] forState:(UIControlStateNormal)];
        addEmoteButton.frame = CGRectMake(0, 0, 30, 30);
        [addEmoteButton addTarget:self action:@selector(tappedAddEmote:) forControlEvents:(UIControlEventTouchDown)];
        
        
        toolbar.items = [NSArray arrayWithObjects:
                         [[UIBarButtonItem alloc] initWithCustomView:seg],
                         [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace)
                                                                       target:nil action:nil],
                         [[UIBarButtonItem alloc] initWithCustomView:addEmoteButton],
                          nil
                          ];
        [self addSubview:toolbar];
    }
    return self;
}

-(void) tappedAddEmote:(UIButton*)button {
    AwfulEmoteChooser *chooser = [AwfulEmoteChooser new];
    pop = [[UIPopoverController alloc] initWithContentViewController:chooser];
    [pop setPopoverContentSize:CGSizeMake(125*4, 768)];
    [pop presentPopoverFromRect:button.frame inView:self permittedArrowDirections:(UIPopoverArrowDirectionDown) animated:YES];
    
}



@end
