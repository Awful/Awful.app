//
//  AwfulEmoticonChooserCellView.m
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoticonChooserCellView.h"

@implementation AwfulEmoticonChooserCellView
@synthesize textLabel = _textLabel;
@synthesize imageView = _imageView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    }
    return self;
}

-(void) layoutSubviews {
    self.imageView.backgroundColor = [UIColor clearColor];
    if (!self.imageView.image) self.imageView.backgroundColor = [UIColor darkGrayColor];
    
    if (!self.textLabel.text) {
        self.imageView.frame = self.frame;
    }
    else {
        self.imageView.frame = CGRectMake(0,
                                          0,
                                          self.frame.size.width,
                                          self.frame.size.height-15);
        
        self.textLabel.frame = CGRectMake(0,
                                          self.frame.size.height-15,
                                          self.frame.size.width,
                                          15);
        self.textLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:self.textLabel];
    }
    [self addSubview:self.imageView];
}

-(UILabel*) textLabel {
    if (_textLabel) return _textLabel;
    
    _textLabel = [UILabel new];
    _textLabel.textAlignment = UITextAlignmentCenter;
    _textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _textLabel.font = [UIFont systemFontOfSize:10];
    return _textLabel;
}

-(UIImageView*) imageView {
    if(_imageView) return _imageView;
    
    _imageView = [UIImageView new];
    _imageView.contentMode = UIViewContentModeCenter;
    return _imageView;
}


@end
