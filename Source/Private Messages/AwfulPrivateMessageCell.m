//  AwfulPrivateMessageCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageCell.h"

@implementation AwfulPrivateMessageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    
    _overlayImageView = [UIImageView new];
    [self.imageView addSubview:_overlayImageView];
    
    self.textLabel.numberOfLines = 2;
    self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    
    self.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.detailTextLabel.enabled = NO;
    
    return self;
}

- (void)setThreadTagHidden:(BOOL)threadTagHidden
{
    if (_threadTagHidden == threadTagHidden) return;
    _threadTagHidden = threadTagHidden;
    self.imageView.hidden = threadTagHidden;
    self.overlayImageView.hidden = threadTagHidden;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect remainder = CGRectInset(self.contentView.bounds, 4, 0);
    
    if (self.threadTagHidden) {
        remainder.origin.x += 11;
        remainder.size.width -= 11;
    } else {
        CGRect tagFrame;
        CGRectDivide(remainder, &tagFrame, &remainder, 45 + 9, CGRectMinXEdge);
        tagFrame.size.width -= 9;
        [self.imageView sizeToFit];
        tagFrame.size.height = CGRectGetHeight(self.imageView.bounds);
        tagFrame.origin.y = CGRectGetMidY(remainder) - CGRectGetHeight(tagFrame) / 2;
        self.imageView.frame = tagFrame;
        
        CGRect tagBounds = self.imageView.bounds;
        [self.overlayImageView sizeToFit];
        CGRect overlayFrame = self.overlayImageView.frame;
        overlayFrame.origin.x = CGRectGetMaxX(tagBounds) - CGRectGetWidth(overlayFrame) + 1;
        overlayFrame.origin.y = CGRectGetMaxY(tagBounds) - CGRectGetHeight(overlayFrame) + 1;
        self.overlayImageView.frame = overlayFrame;
    }
    
    self.separatorInset = UIEdgeInsetsMake(0, CGRectGetMinX(remainder), 0, 0);
    
    self.textLabel.frame = CGRectMake(0, 0, CGRectGetWidth(remainder), 0);
    [self.textLabel sizeToFit];
    self.detailTextLabel.frame = CGRectMake(0, 0, CGRectGetWidth(remainder), 0);
    [self.detailTextLabel sizeToFit];
    CGFloat totalHeight = CGRectGetHeight(self.textLabel.bounds) + 2 + CGRectGetHeight(self.detailTextLabel.bounds);
    CGRect textRect = CGRectInset(remainder, 0, (CGRectGetHeight(remainder) - totalHeight) / 2);
    CGRect subjectFrame = textRect;
    subjectFrame.size.height = CGRectGetHeight(self.textLabel.bounds);
    self.textLabel.frame = subjectFrame;
    CGRect fromFrame = textRect;
    fromFrame.size.height = CGRectGetHeight(self.detailTextLabel.bounds);
    fromFrame.origin.y = CGRectGetMaxY(textRect) - CGRectGetHeight(fromFrame);
    self.detailTextLabel.frame = fromFrame;
}

@end
