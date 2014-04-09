//  AwfulForumCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumCell.h"

@implementation AwfulForumCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    
    _disclosureButton = [UIButton new];
    _disclosureButton.imageView.contentMode = UIViewContentModeCenter;
    [_disclosureButton setImage:[UIImage imageNamed:@"forum-arrow-right"] forState:UIControlStateNormal];
    [_disclosureButton setImage:[UIImage imageNamed:@"forum-arrow-down"] forState:UIControlStateSelected];
    _disclosureButton.hidden = YES;
    [self.contentView addSubview:_disclosureButton];
    
    self.textLabel.numberOfLines = 2;
    self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    self.textLabel.minimumScaleFactor = 0.95;
    
    _favoriteButton = [UIButton new];
    [_favoriteButton setImage:[UIImage imageNamed:@"star-off"] forState:UIControlStateNormal];
    [self.contentView addSubview:_favoriteButton];
    
    return self;
}

- (void)setSubforumLevel:(NSInteger)subforumLevel
{
    if (_subforumLevel == subforumLevel) return;
    _subforumLevel = subforumLevel;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect remainder = self.contentView.bounds;
    
    CGRect disclosureFrame;
    CGRectDivide(remainder, &disclosureFrame, &remainder, 32, CGRectMinXEdge);
    self.disclosureButton.frame = disclosureFrame;
    
    CGRect favoriteFrame;
    CGRectDivide(remainder, &favoriteFrame, &remainder, 32, CGRectMaxXEdge);
    [self.favoriteButton sizeToFit];
    favoriteFrame.size.height = CGRectGetHeight(self.favoriteButton.bounds);
    favoriteFrame.origin.y = CGRectGetMidY(remainder) - CGRectGetHeight(favoriteFrame) / 2 - 2;
    self.favoriteButton.frame = favoriteFrame;
    
    CGRect nameFrame = CGRectInset(remainder, 4, 2);
    CGFloat indent = self.subforumLevel * 15;
    nameFrame.origin.x += indent;
    nameFrame.size.width -= indent;
    self.textLabel.frame = nameFrame;
}

@end
