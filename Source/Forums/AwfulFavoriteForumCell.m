//  AwfulFavoriteForumCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFavoriteForumCell.h"

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
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0,==0@900)-[name]-(>=0,==0@900)-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:nil
                                               views:@{ @"name": self.textLabel }]];
}

@end
