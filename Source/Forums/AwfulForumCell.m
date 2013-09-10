//  AwfulForumCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumCell.h"

@implementation AwfulForumCell

// Redeclare textLabel so we can make our own which participates in auto layout.
@synthesize textLabel = _textLabel;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) return nil;
    
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
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[disclosure(32)]-_-[name]-_-[favorite(disclosure)]|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:@{ @"_": @4 }
                                               views:@{ @"disclosure": self.disclosureButton,
                                                        @"name": self.textLabel,
                                                        @"favorite": self.favoriteButton }]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0,==0@900)-[name]-(>=0,==0@900)-|"
                                             options:0
                                             metrics:nil
                                               views:@{ @"name": self.textLabel }]];
}

- (void)willTransitionToState:(UITableViewCellStateMask)state
{
    
}

@end
