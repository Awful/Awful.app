//  AwfulFavoriteForumCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFavoriteForumCell.h"

@implementation AwfulFavoriteForumCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    
    self.imageView.image = [UIImage imageNamed:@"star-on"];
    self.imageView.contentMode = UIViewContentModeCenter;
    
    self.textLabel.numberOfLines = 2;
    self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.textLabel.minimumScaleFactor = 0.5;
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect remainder = self.contentView.bounds;
    
    CGRect favoriteFrame;
    CGRectDivide(remainder, &favoriteFrame, &remainder, 32, CGRectMinXEdge);
    [self.imageView sizeToFit];
    favoriteFrame.size.height = CGRectGetHeight(self.imageView.bounds);
    favoriteFrame.origin.y = CGRectGetMidY(remainder) - CGRectGetHeight(favoriteFrame) / 2 - 2;
    self.imageView.frame = favoriteFrame;
    
    CGRect nameFrame = CGRectInset(remainder, 4, 4);
    nameFrame.size.width -= CGRectGetWidth(favoriteFrame);
    self.textLabel.frame = nameFrame;
}

@end
