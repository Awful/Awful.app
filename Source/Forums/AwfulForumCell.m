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
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-_-[name]-_-|"
                                             options:0
                                             metrics:@{ @"_": @8 }
                                               views:@{ @"name": self.textLabel }]];
}

- (void)willTransitionToState:(UITableViewCellStateMask)state
{
    
}

@end

@implementation AwfulFavoriteForumCell

// Redeclare imageView and textLabel so we can make our own which participate in auto layout.
@synthesize imageView = _imageView;
@synthesize textLabel = _textLabel;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) return nil;
    
    _imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"star-on"]];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.contentMode = UIViewContentModeCenter;
    [self.contentView addSubview:_imageView];
    
    _textLabel = [UILabel new];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.numberOfLines = 2;
    _textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [self.contentView addSubview:_textLabel];
    
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
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[favorite(width)]-[name]-width-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:@{ @"width": @32 }
                                               views:@{ @"favorite": self.imageView,
                                                        @"name": self.textLabel }]];
    [self.contentView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-margin-[name]-margin-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:@{ @"margin": @8 }
                                               views:@{ @"name": self.textLabel }]];
}

@end
