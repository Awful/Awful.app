//
//  AwfulPostComposerCell.m
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerCell.h"
#import "AwfulPostComposerView.h"

@implementation AwfulPostComposerCell
@synthesize composerView = _composerView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _composerView = [AwfulPostComposerView new];
        self.composerView.frame = self.contentView.frame;
        self.composerView.text = @"Your shitty post";
        //self.composerView.delegate = self;
        [self.contentView addSubview:self.composerView];
    }
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.composerView.frame = self.contentView.frame;
}

@end
