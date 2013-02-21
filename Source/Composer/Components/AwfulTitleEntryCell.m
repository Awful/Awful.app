//
//  AwfulTitleEntryCell.m
//  Awful
//
//  Created by me on 2/4/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTitleEntryCell.h"
#import "AwfulThreadTags.h"
#import "AwfulEmoticonChooserViewController.h"

@implementation AwfulTitleEntryCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        self.textField.placeholder = @"Thread title";
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.imageView.image = [UIImage threadTagNamed:@"shitpost.png"];
        self.imageView.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapThreadTag:)];
        [self.imageView addGestureRecognizer:tap];
    }
    return self;
}

- (void)didTapThreadTag:(UIGestureRecognizer*)tap {
    [self.delegate chooseThreadTag:self.imageView];
}

@end
