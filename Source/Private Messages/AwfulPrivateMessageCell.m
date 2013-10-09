//  AwfulPrivateMessageCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageCell.h"

@implementation AwfulPrivateMessageCell
{
    UIView *_topSpacer;
    UIView *_bottomSpacer;
}

// Redeclare imageView, textLabel, and detailTextLabel so we can make our own that participate in auto layout.
@synthesize imageView = _imageView;
@synthesize textLabel = _textLabel;
@synthesize detailTextLabel = _detailTextLabel;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) return nil;
    
    _imageView = [UIImageView new];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_imageView];
    
    _overlayImageView = [UIImageView new];
    _overlayImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_imageView addSubview:_overlayImageView];
    
    _textLabel = [UILabel new];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.numberOfLines = 2;
    _textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [self.contentView addSubview:_textLabel];
    
    _detailTextLabel = [UILabel new];
    _detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _detailTextLabel.enabled = NO;
    [self.contentView addSubview:_detailTextLabel];
    
    _topSpacer = [UIView new];
    _topSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_topSpacer];
    
    _bottomSpacer = [UIView new];
    _bottomSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_bottomSpacer];
    
    [self setNeedsUpdateConstraints];
    
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (void)updateConstraints
{
    NSDictionary *views = @{ @"tag": self.imageView,
                             @"subject": self.textLabel,
                             @"sender": self.detailTextLabel,
                             @"overlay": self.overlayImageView,
                             @"topSpacer": _topSpacer,
                             @"bottomSpacer": _bottomSpacer };
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-5-[tag(45)]-9-[subject]-(>=5,==5@900)-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"tag"]
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self.contentView
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"sender"]
                                  attribute:NSLayoutAttributeLeft
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"subject"]
                                  attribute:NSLayoutAttributeLeft
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"sender"]
                                  attribute:NSLayoutAttributeRight
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"subject"]
                                  attribute:NSLayoutAttributeRight
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[topSpacer(bottomSpacer)][subject][sender][bottomSpacer(topSpacer)]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.imageView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"overlay"]
                                  attribute:NSLayoutAttributeRight
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"tag"]
                                  attribute:NSLayoutAttributeRight
                                 multiplier:1
                                   constant:1]];
    [self.imageView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"overlay"]
                                  attribute:NSLayoutAttributeBottom
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"tag"]
                                  attribute:NSLayoutAttributeBottom
                                 multiplier:1
                                   constant:2]];
    [super updateConstraints];
}

@end
