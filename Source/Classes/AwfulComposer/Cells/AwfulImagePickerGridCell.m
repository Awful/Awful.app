//
//  AwfulImagePickerGridCell.m
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulImagePickerGridCell.h"
#import "FVGifAnimation.h"

@implementation AwfulImagePickerGridCell
@synthesize showLabel = _showLabel;

- (id)init
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AwfulImagePickerGridCell"];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.detailTextLabel.hidden = YES;
    self.imageView.frame = self.contentView.frame;
    self.imageView.contentMode = UIViewContentModeCenter;
    
    if (self.showLabel) {
        [self.detailTextLabel sizeToFit];
        
        self.imageView.fsH = self.contentView.fsH - self.detailTextLabel.fsH - 2;
        self.detailTextLabel.hidden = NO;
        self.detailTextLabel.foY = self.imageView.fsH + 2;
        self.detailTextLabel.fsW = self.contentView.fsW;
        self.detailTextLabel.foX = self.contentView.foX;
        self.detailTextLabel.font = [UIFont systemFontOfSize:11];
        self.detailTextLabel.textAlignment = UITextAlignmentCenter;
    }
    
    else {
    }
}

-(void) setImagePath:(NSString *)imagePath {
    
    self.imageView.image = [UIImage imageNamed:imagePath.lastPathComponent];
    NSString* path = [[NSBundle mainBundle] pathForResource:imagePath.lastPathComponent ofType:nil];
    self.animation = [[FVGifAnimation alloc] initWithData:
                      [NSData dataWithContentsOfFile:path]
                      ];
    
    [self.animation setAnimationToImageView:self.imageView];
    [self.imageView startAnimating];
    
    
}


@end
