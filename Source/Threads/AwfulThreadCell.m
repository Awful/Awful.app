//  AwfulThreadCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadCell.h"

@implementation AwfulThreadCell
{
    UIImageView *_pagesIconImageView;
    UIView *_topSpacer;
    UIView *_bottomSpacer;
}

// Redeclare textLabel and detailTextLabel so we can make our own which participate in auto layout.
@synthesize textLabel = _textLabel;
@synthesize detailTextLabel = _detailTextLabel;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) return nil;
    
    _stickyImageView = [UIImageView new];
    _stickyImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _stickyImageView.contentMode = UIViewContentModeTopRight;
    [self.contentView addSubview:_stickyImageView];
    
    _tagAndRatingView = [AwfulThreadTagAndRatingView new];
    _tagAndRatingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_tagAndRatingView];
    
    _textLabel = [UILabel new];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.numberOfLines = 2;
    _textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [_textLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:_textLabel];
    
    _numberOfPagesLabel = [UILabel new];
    _numberOfPagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _numberOfPagesLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _numberOfPagesLabel.enabled = NO;
    [self.contentView addSubview:_numberOfPagesLabel];
    
    _pagesIconImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pages"]];
    _pagesIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_pagesIconImageView];
    
    _detailTextLabel = [UILabel new];
    _detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    _detailTextLabel.enabled = NO;
    [self.contentView addSubview:_detailTextLabel];
    
    _badgeLabel = [UILabel new];
    _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:_textLabel.font.pointSize];
    _badgeLabel.textAlignment = NSTextAlignmentRight;
    [_badgeLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:_badgeLabel];
    
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
    NSDictionary *views = @{ @"tagAndRating": self.tagAndRatingView,
                             @"name": self.textLabel,
                             @"pages": self.numberOfPagesLabel,
                             @"pagesIcon": _pagesIconImageView,
                             @"detail": self.detailTextLabel,
                             @"badge": self.badgeLabel,
                             @"sticky": self.stickyImageView,
                             @"topSpacer": _topSpacer,
                             @"bottomSpacer": _bottomSpacer };
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"tagAndRating"]
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
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-5-[tagAndRating(45)]-9-[name]-5-[badge]-5-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[topSpacer(bottomSpacer)][name][pages][bottomSpacer(topSpacer)]|"
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
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[pages]-2-[pagesIcon]-4-[detail]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"pagesIcon"]
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"pages"]
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"detail"]
                                  attribute:NSLayoutAttributeBaseline
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"pages"]
                                  attribute:NSLayoutAttributeBaseline
                                 multiplier:1
                                   constant:0]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[sticky]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[sticky]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[topSpacer(0)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomSpacer(0)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [super updateConstraints];
}

@end
