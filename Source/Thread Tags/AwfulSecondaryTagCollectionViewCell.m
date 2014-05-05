//  AwfulSecondaryTagCollectionViewCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSecondaryTagCollectionViewCell.h"
#import "AwfulTheme.h"
#import "UIColor+AwfulConvenience.h"

@interface AwfulSecondaryTagCollectionViewCell ()
@property (strong, nonatomic) UIColor *drawColor;
@property (strong, nonatomic) NSString *titleText;
@property (strong, nonatomic) UIImageView *selectedIcon;
@end

@implementation AwfulSecondaryTagCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIImage *selectedTick = [UIImage imageNamed:@"selected-tick-icon"];
    self.selectedIcon = [[UIImageView alloc] initWithImage:selectedTick];
    self.selectedIcon.hidden = YES;
    [self.contentView addSubview:self.selectedIcon];
    
    self.backgroundColor = [UIColor clearColor];
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

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    self.selectedIcon.hidden = !selected;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [self.drawColor CGColor]);
    CGContextSetStrokeColorWithColor(context, [self.drawColor CGColor]);
    
    UIColor *firstLetterColor = nil;
    
    // Only use width to ensure circle is drawn, not oval
    CGRect circleRect = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect),
                                   CGRectGetWidth(rect), CGRectGetWidth(rect));
    circleRect = CGRectInset(circleRect, 5, 5);
    if (self.selected) {
        CGContextFillEllipseInRect(context, circleRect);
        firstLetterColor = [UIColor whiteColor];
    } else {
        CGContextSetLineWidth(context, 2);
        CGContextStrokeEllipseInRect(context, circleRect);
        firstLetterColor = self.drawColor;
    }
    
    NSString *firstLetter = [self.titleText substringWithRange:NSMakeRange(0, 1)];
    NSDictionary *letterAttrs = @{NSForegroundColorAttributeName: firstLetterColor,
                                  NSFontAttributeName: [UIFont systemFontOfSize:24]};
    CGSize letterSize = [firstLetter sizeWithAttributes:letterAttrs];
    CGFloat letterPosX = CGRectGetMidX(circleRect) - (letterSize.width/2);
    CGFloat letterPosY = CGRectGetMidY(circleRect) - (letterSize.height/2);
    CGRect firstLetterRect = CGRectMake(letterPosX, letterPosY, letterSize.width, letterSize.height);
    [firstLetter drawInRect:firstLetterRect withAttributes:letterAttrs];
    
    NSDictionary *titleAttrs = @{NSForegroundColorAttributeName: self.titleTextColor,
                                 NSFontAttributeName: [UIFont boldSystemFontOfSize:12]};
    CGSize titleSize = [self.titleText sizeWithAttributes:titleAttrs];
    CGFloat titlePosX = (CGRectGetWidth(rect) - titleSize.width) / 2;
    CGFloat titlePosY = CGRectGetHeight(rect) - titleSize.height;
    CGRect textRect = CGRectMake(titlePosX, titlePosY, titleSize.width, titleSize.height);
    [self.titleText drawInRect:textRect withAttributes:titleAttrs];
}

static const CGFloat kSelectedIconSize = 31;
- (void)layoutSubviews
{
    // Only use width to ensure tick is placed on circle, not text
    CGFloat pos = self.bounds.size.width - kSelectedIconSize;
    self.selectedIcon.frame = CGRectMake(pos, pos, kSelectedIconSize, kSelectedIconSize);
}

@end
