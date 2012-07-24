//
//  AwfulPostComposerInputAccessoryView.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerInputAccessoryView.h"

@implementation AwfulPostComposerInputAccessoryView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor greenColor];
        
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:self.frame];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:
                                   [NSArray arrayWithObjects:@"1",@"2",@"1",@"2",@"1",@"2",@"1",@"2", nil]
                                   
                                   ];
        seg.segmentedControlStyle = UISegmentedControlStyleBar;
        

        toolbar.items = [NSArray arrayWithObjects:
                         [[UIBarButtonItem alloc] initWithCustomView:seg],
                         [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemFlexibleSpace)
                                                                       target:nil action:nil],
                          nil
                          ];
        [self addSubview:toolbar];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
