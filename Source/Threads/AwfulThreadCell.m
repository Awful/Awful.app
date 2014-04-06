//  AwfulThreadCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadCell.h"
#import "AwfulSettings.h"

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
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    
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
    [_textLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:_textLabel];
    
    _numberOfPagesLabel = [UILabel new];
    _numberOfPagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_numberOfPagesLabel];
    
    UIImage *pageTemplateImage = [[UIImage imageNamed:@"pages"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _pagesIconImageView = [[UIImageView alloc] initWithImage:pageTemplateImage];
    _pagesIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_pagesIconImageView];
    
    _detailTextLabel = [UILabel new];
    _detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_detailTextLabel];
    
    [self setFontName:nil];
    
    _badgeLabel = [UILabel new];
    _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:_textLabel.font.pointSize];
    _badgeLabel.textAlignment = NSTextAlignmentRight;
    [_badgeLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:_badgeLabel];
    
    _topSpacer = [UIView new];
    _topSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_topSpacer];
    _bottomSpacer = [UIView new];
    _bottomSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_bottomSpacer];
    
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
     [NSLayoutConstraint constraintWithItem:views[@"badge"]
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self.contentView
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
	
	if (AwfulSettings.settings.showThreadTags) {
		
		[self.contentView addConstraint:
		 [NSLayoutConstraint constraintWithItem:views[@"tagAndRating"]
									  attribute:NSLayoutAttributeCenterY
									  relatedBy:NSLayoutRelationEqual
										 toItem:self.contentView
									  attribute:NSLayoutAttributeCenterY
									 multiplier:1
									   constant:0]];
		
		[self.contentView addConstraints:
		 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-5-[tagAndRating(45)]-9-[name]-6-[badge]-8-|"
												 options:0
												 metrics:nil
												   views:views]];
	}
	else
	{
		[self.contentView addConstraints:
		 [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-5-[name]-6-[badge]-8-|"
												 options:0
												 metrics:nil
												   views:views]];
	}
	
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
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[pages]-2-[pagesIcon]-5-[detail]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self.contentView addConstraint:
     [NSLayoutConstraint constraintWithItem:views[@"pagesIcon"]
                                  attribute:NSLayoutAttributeBottom
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:views[@"pages"]
                                  attribute:NSLayoutAttributeBaseline
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
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

- (void)setLightenBadgeLabel:(BOOL)lightenBadgeLabel
{
    _lightenBadgeLabel = lightenBadgeLabel;
    if (lightenBadgeLabel) {
        self.badgeLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:_textLabel.font.pointSize];
    } else {
        self.badgeLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:_textLabel.font.pointSize];
    }
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    self.numberOfPagesLabel.textColor = self.tintColor;
    self.detailTextLabel.textColor = self.tintColor;
    _pagesIconImageView.tintColor = self.tintColor;
}

- (NSString *)fontName
{
    return self.textLabel.font.fontName;
}

- (void)setFontName:(NSString *)fontName
{
    UIFontDescriptor *textLabelDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
    _textLabel.font = [UIFont fontWithName:fontName size:textLabelDescriptor.pointSize];
    UIFontDescriptor *numberOfPagesDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleCaption1];
    _numberOfPagesLabel.font = [UIFont fontWithName:fontName size:numberOfPagesDescriptor.pointSize];
    UIFontDescriptor *detailTextLabelDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleCaption2];
    _detailTextLabel.font = [UIFont fontWithName:fontName size:detailTextLabelDescriptor.pointSize];
}

@end
