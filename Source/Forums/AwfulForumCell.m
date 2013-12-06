//  AwfulForumCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumCell.h"

@implementation AwfulForumCell
{
    UIView *_subforumIndenter;
    NSLayoutConstraint *_indenterWidthConstraint;
    NSMutableArray *_indenterConstraints;
}

// Redeclare textLabel so we can make our own which participates in auto layout.
@synthesize textLabel = _textLabel;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    
    _indenterConstraints = [NSMutableArray new];
    
    _disclosureButton = [UIButton new];
    _disclosureButton.translatesAutoresizingMaskIntoConstraints = NO;
    _disclosureButton.imageView.contentMode = UIViewContentModeCenter;
    [_disclosureButton setImage:[UIImage imageNamed:@"forum-arrow-right"] forState:UIControlStateNormal];
    [_disclosureButton setImage:[UIImage imageNamed:@"forum-arrow-down"] forState:UIControlStateSelected];
    _disclosureButton.hidden = YES;
    [self.contentView addSubview:_disclosureButton];
    
    _textLabel = [UILabel new];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.numberOfLines = 2;
    _textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _textLabel.minimumScaleFactor = 0.5;
    [self.contentView addSubview:_textLabel];
    
    _favoriteButton = [UIButton new];
    _favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_favoriteButton setImage:[UIImage imageNamed:@"star-off"] forState:UIControlStateNormal];
    _favoriteButton.hidden = NO;
    [self.contentView addSubview:_favoriteButton];
    
    _subforumIndenter = [UIView new];
    _subforumIndenter.translatesAutoresizingMaskIntoConstraints = NO;
    _subforumIndenter.backgroundColor = [UIColor colorWithWhite:0.376 alpha:1];
    [self.contentView addSubview:_subforumIndenter];
    
    NSDictionary *views = @{ @"disclosure": self.disclosureButton,
                             @"name": self.textLabel,
                             @"favorite": self.favoriteButton };
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[disclosure(32)]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[name]-4-[favorite(disclosure)]|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0,==0@900)-[name]-(>=0,==0@900)-|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [_subforumIndenter addConstraint:
     [NSLayoutConstraint constraintWithItem:_subforumIndenter
                                  attribute:NSLayoutAttributeHeight
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:nil
                                  attribute:NSLayoutAttributeNotAnAttribute
                                 multiplier:1
                                   constant:1]];
    _indenterWidthConstraint = [NSLayoutConstraint constraintWithItem:_subforumIndenter
                                                            attribute:NSLayoutAttributeWidth
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:nil
                                                            attribute:NSLayoutAttributeNotAnAttribute
                                                           multiplier:1
                                                             constant:0];
    [_subforumIndenter addConstraint:_indenterWidthConstraint];
    [self setNeedsUpdateConstraints];
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (void)willTransitionToState:(UITableViewCellStateMask)state
{
    
}

- (void)updateConstraints
{
    if (self.subforumLevel > 0) {
        [_indenterConstraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:[disclosure]-4-[indenter]-6-[name]"
                                                 options:NSLayoutFormatAlignAllCenterY
                                                 metrics:nil
                                                   views:@{ @"disclosure": self.disclosureButton,
                                                            @"indenter": _subforumIndenter,
                                                            @"name": self.textLabel }]];
    } else {
        [_indenterConstraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:[disclosure]-4-[name]"
                                                 options:NSLayoutFormatAlignAllCenterY
                                                 metrics:nil
                                                   views:@{ @"disclosure": self.disclosureButton,
                                                            @"name": self.textLabel }]];
    }
    [self.contentView addConstraints:_indenterConstraints];
    [super updateConstraints];
}

- (void)setSubforumLevel:(NSInteger)subforumLevel
{
    NSInteger old = _subforumLevel;
    _subforumLevel = subforumLevel;
    _indenterWidthConstraint.constant = 15 * MAX(0, subforumLevel);
    if ((old < 1 && subforumLevel > 0) || (old > 0 && subforumLevel < 1)) {
        [self.contentView removeConstraints:_indenterConstraints];
        [_indenterConstraints removeAllObjects];
        [self setNeedsUpdateConstraints];
    }
}

@end
