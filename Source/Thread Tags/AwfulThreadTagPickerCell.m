//  AwfulThreadTagPickerCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagPickerCell.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulThreadTagView.h"

@interface AwfulThreadTagPickerCell ()

@property (strong, nonatomic) AwfulThreadTagView *tagView;
@property (strong, nonatomic) UILabel *imageNameLabel;
@property (strong, nonatomic) UIImageView *selectedIcon;

@end

@implementation AwfulThreadTagPickerCell

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.imageNameLabel = [UILabel new];
        self.imageNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.imageNameLabel.numberOfLines = 0;
        self.imageNameLabel.lineBreakMode = NSLineBreakByCharWrapping;
        [self.contentView addSubview:self.imageNameLabel];
        
        self.tagView = [AwfulThreadTagView new];
        self.tagView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:self.tagView];
        
        UIImage *selectedTick = [UIImage imageNamed:@"selected-tick-icon"];
        self.selectedIcon = [[UIImageView alloc] initWithImage:selectedTick];
        self.selectedIcon.hidden = YES;
        [self.contentView addSubview:self.selectedIcon];
    }
    return self;
}

- (UIImage *)image
{
    return self.tagView.tagImage;
}

- (void)setImage:(UIImage *)icon
{
    self.tagView.tagImage = icon;
}

- (NSString *)tagImageName
{
    return self.imageNameLabel.text;
}

- (void)setTagImageName:(NSString *)tagImageName
{
    self.imageNameLabel.text = tagImageName;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    self.selectedIcon.hidden = !selected;
}

static const CGFloat kSelectedIconSize = 31;

- (void)layoutSubviews
{
    self.imageNameLabel.frame = self.bounds;
    self.tagView.frame = self.bounds;
    self.selectedIcon.frame = CGRectMake(self.bounds.size.width-kSelectedIconSize,
                                         self.bounds.size.height-kSelectedIconSize,
                                         kSelectedIconSize, kSelectedIconSize);
}

@end

@interface AwfulSecondaryTagPickerCell ()

@property (strong, nonatomic) UIColor *drawColor;
@property (strong, nonatomic) NSString *titleText;

@end

@implementation AwfulSecondaryTagPickerCell

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.titleTextColor = [UIColor whiteColor];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setTagImageName:(NSString *)tagImageName
{
    [self willChangeValueForKey:@"tagImageName"];
    _tagImageName = tagImageName;
    [self didChangeValueForKey:@"tagImageName"];
    
    NSURL *tagsInfoURL = [[NSBundle mainBundle] URLForResource:@"SecondaryTags" withExtension:@"plist"];
    NSDictionary *tagsDictionary = [NSDictionary dictionaryWithContentsOfURL:tagsInfoURL];
    NSDictionary *tagInfo = tagsDictionary[tagImageName];
    self.titleText = tagInfo[@"title"] ?: @"?????";
    self.drawColor = [UIColor awful_colorWithHexCode:tagInfo[@"color"]] ?: [UIColor redColor];
}

- (void)setTitleTextColor:(UIColor *)titleTextColor
{
    _titleTextColor = titleTextColor;
    [self setNeedsDisplay];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSDictionary *titleAttrs = @{ NSForegroundColorAttributeName: self.titleTextColor,
                                  NSFontAttributeName: [UIFont systemFontOfSize:12] };
    CGSize titleSize = [self.titleText sizeWithAttributes:titleAttrs];
    CGFloat titlePosX = (CGRectGetWidth(self.bounds) - titleSize.width) / 2;
    CGFloat titlePosY = CGRectGetHeight(self.bounds) - titleSize.height;
    CGRect textRect = CGRectMake(titlePosX, titlePosY, titleSize.width, titleSize.height);
    [self.titleText drawInRect:textRect withAttributes:titleAttrs];
    
    CGFloat diameter = CGRectGetMinY(textRect);
    CGRect circleRect = CGRectInset(CGRectMake(CGRectGetMidX(self.bounds) - diameter / 2, 0, diameter, diameter), 5, 5);
    CGContextSetFillColorWithColor(context, self.drawColor.CGColor);
    CGContextSetStrokeColorWithColor(context, self.drawColor.CGColor);
    CGContextSetLineWidth(context, 1);
    if (self.selected) {
        CGContextFillEllipseInRect(context, circleRect);
    } else {
        CGContextStrokeEllipseInRect(context, circleRect);
    }
    
    NSString *firstLetter = [self.titleText substringWithRange:NSMakeRange(0, 1)];
    NSDictionary *letterAttrs = @{ NSForegroundColorAttributeName: self.selected ? [UIColor whiteColor] : self.drawColor,
                                   NSFontAttributeName: [UIFont systemFontOfSize:24] };
    CGSize letterSize = [firstLetter sizeWithAttributes:letterAttrs];
    CGFloat letterPosX = CGRectGetMidX(circleRect) - (letterSize.width / 2);
    CGFloat letterPosY = CGRectGetMidY(circleRect) - (letterSize.height / 2);
    CGRect firstLetterRect = CGRectMake(letterPosX, letterPosY, letterSize.width, letterSize.height);
    [firstLetter drawInRect:firstLetterRect withAttributes:letterAttrs];
}

@end
