//  AwfulThreadCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadCell.h"

@implementation AwfulThreadCell
{
    UIView *_topSpacer;
    UIView *_bottomSpacer;
}

// Redeclare textLabel and detailTextLabel so we can make our own which participate in auto layout.
@synthesize textLabel = _textLabel;
@synthesize detailTextLabel = _detailTextLabel;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) return nil;
    
    _tagAndRatingView = [AwfulThreadTagAndRatingView new];
    _tagAndRatingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_tagAndRatingView];
    
    _textLabel = [UILabel new];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.numberOfLines = 2;
    _textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [self.contentView addSubview:_textLabel];
    
    _numberOfPagesLabel = [UILabel new];
    _numberOfPagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _numberOfPagesLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [self.contentView addSubview:_numberOfPagesLabel];
    
    _detailTextLabel = [UILabel new];
    _detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [self.contentView addSubview:_detailTextLabel];
    
    _badgeLabel = [UILabel new];
    _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFontDescriptor *normalBodyFont = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
    UIFontDescriptor *boldBodyFont = [normalBodyFont fontDescriptorWithSymbolicTraits:normalBodyFont.symbolicTraits & UIFontDescriptorTraitBold];
    _badgeLabel.font = [UIFont fontWithDescriptor:boldBodyFont size:0];
    _badgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:_badgeLabel];
    
    _stickyImageView = [UIImageView new];
    _stickyImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _stickyImageView.contentMode = UIViewContentModeTopRight;
    [self.contentView addSubview:_stickyImageView];
    
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
    [super updateConstraints];
    NSDictionary *views = @{ @"tag": self.tagAndRatingView,
                             @"name": self.textLabel,
                             @"pages": self.numberOfPagesLabel,
                             @"detail": self.detailTextLabel,
                             @"badge": self.badgeLabel,
                             @"sticky": self.stickyImageView,
                             @"topSpacer": _topSpacer,
                             @"bottomSpacer": _bottomSpacer };
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"tag"]
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self.contentView
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"badge"]
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self.contentView
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-5-[tag(45)]-9-[name]-8-[badge(>=tag,==tag@900)]-8-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[topSpacer(bottomSpacer)][name]-3-[pages][bottomSpacer(topSpacer)]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"pages"]
                                  attribute:NSLayoutAttributeLeft
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"name"]
                                  attribute:NSLayoutAttributeLeft
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[pages]-4-[detail]"
                                             options:NSLayoutFormatAlignAllBaseline
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[sticky]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[sticky]"
                                             options:0
                                             metrics:nil
                                               views:views]];
}

@end
