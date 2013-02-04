//
//  AwfulTitleEntryCell.m
//  Awful
//
//  Created by me on 2/4/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTitleEntryCell.h"
#import "AwfulThreadTags.h"

@implementation AwfulTitleEntryCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        self.textField.placeholder = @"Thread title";
        
        
        self.imageView.image = [UIImage threadTagNamed:@"shitpost.png"];
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
