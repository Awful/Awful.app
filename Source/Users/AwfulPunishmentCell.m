//  AwfulPunishmentCell.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPunishmentCell.h"

@implementation AwfulPunishmentCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier])) {
        self.contentView.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
        
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        self.textLabel.font = [UIFont boldSystemFontOfSize:15];
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.detailTextLabel.font = [UIFont systemFontOfSize:13];
        self.detailTextLabel.backgroundColor = [UIColor clearColor];
        
        _reasonLabel = [UILabel new];
        _reasonLabel.numberOfLines = 0;
        _reasonLabel.font = [UIFont systemFontOfSize:reasonFontSize];
        _reasonLabel.backgroundColor = [UIColor clearColor];
        _reasonLabel.highlightedTextColor = self.textLabel.highlightedTextColor;
        [self.contentView addSubview:_reasonLabel];
    }
    return self;
}

static const CGFloat reasonFontSize = 15;

+ (CGFloat)rowHeightWithBanReason:(NSString *)banReason width:(CGFloat)width
{
    const UIEdgeInsets reasonInsets = (UIEdgeInsets){
        .left = 10, .right = 30,
        .top = 63, .bottom = 10,
    };
    width -= reasonInsets.left + reasonInsets.right;
    CGRect reasonLabelRect = [banReason boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:reasonFontSize] }
                                                     context:nil];
    return ceil(CGRectGetHeight(reasonLabelRect)) + reasonInsets.top + reasonInsets.bottom;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    UIImage *backgroundImage = BackgroundImageWithColor(self.backgroundColor);
    if (!self.backgroundView) self.backgroundView = [UIImageView new];
    ((UIImageView *)self.backgroundView).image = backgroundImage;
}

static UIImage * BackgroundImageWithColor(UIColor *color)
{
    static NSCache *backgroundImageCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        backgroundImageCache = [NSCache new];
        backgroundImageCache.name = @"AwfulPunishmentCell background image cache";
    });
    UIImage *backgroundImage = [backgroundImageCache objectForKey:color];
    if (!backgroundImage) {
        CGSize size = CGSizeMake(40, 56);
        UIColor *topColor = color;
        UIColor *shadowColor = [UIColor colorWithWhite:0.5 alpha:0.2];
        UIColor *bottomColor = BottomColorForBackgroundColor(color);
        
        UIGraphicsBeginImageContextWithOptions(size, YES, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        // Subtract 2: 1 for shadow, 1 for resizable part.
        CGRect topHalf = CGRectMake(0, 0, size.width, size.height - 2);
        
        CGContextSaveGState(context); {
            CGContextSetFillColorWithColor(context, bottomColor.CGColor);
            CGContextFillRect(context, (CGRect){ .size = size });
        } CGContextRestoreGState(context);
        
        CGContextSaveGState(context); {
        
            // For whatever reason drawing a shadow in the little triangular notch draws the shadow all the way down, like a stripe. We clip first to prevent the stripe.
            CGContextClipToRect(context, CGRectInset(topHalf, 0, -1));
            
            CGContextMoveToPoint(context, CGRectGetMinX(topHalf), CGRectGetMinY(topHalf));
            CGContextAddLineToPoint(context, CGRectGetMinX(topHalf), CGRectGetMaxY(topHalf));
            CGContextAddLineToPoint(context, CGRectGetMinX(topHalf) + 25, CGRectGetMaxY(topHalf));
            CGContextAddLineToPoint(context, CGRectGetMinX(topHalf) + 31, CGRectGetMaxY(topHalf) - 4);
            CGContextAddLineToPoint(context, CGRectGetMinX(topHalf) + 37, CGRectGetMaxY(topHalf));
            CGContextAddLineToPoint(context, CGRectGetMaxX(topHalf), CGRectGetMaxY(topHalf));
            CGContextAddLineToPoint(context, CGRectGetMaxX(topHalf), CGRectGetMinY(topHalf));
            CGContextSetFillColorWithColor(context, topColor.CGColor);
            CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1, shadowColor.CGColor);
            CGContextFillPath(context);
        } CGContextRestoreGState(context);
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIEdgeInsets capInsets = UIEdgeInsetsMake(size.height - 1, size.width - 1, 0, 0);
        backgroundImage = [image resizableImageWithCapInsets:capInsets];
        [backgroundImageCache setObject:backgroundImage forKey:color];
    }
    return backgroundImage;
}

static UIColor * BottomColorForBackgroundColor(UIColor *color)
{
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    if (brightness >= 0.5) {
        brightness = MAX(brightness - 0.05, 0.0);
    } else {
        brightness = MIN(brightness + 0.05, 1.0);
    }
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (void)layoutSubviews
{
    const UIEdgeInsets cellMargin = (UIEdgeInsets){
        .left = 10, .right = 10,
        .top = 5, .bottom = 10,
    };
    
    self.imageView.frame = CGRectMake(cellMargin.left, cellMargin.top - 1, 44, 44);
    const CGFloat imageViewRightMargin = 10;
    const CGFloat imageViewBottomMargin = 12;
    
    CGRect textLabelFrame = (CGRect){
        .origin = { CGRectGetMaxX(self.imageView.frame) + imageViewRightMargin, 9 },
        .size.height = self.textLabel.font.lineHeight,
    };
    textLabelFrame.size.width = (CGRectGetWidth(self.contentView.bounds) - CGRectGetMinX(textLabelFrame) - cellMargin.right);
    self.textLabel.frame = textLabelFrame;
    self.detailTextLabel.frame = CGRectOffset(textLabelFrame, 0, CGRectGetHeight(textLabelFrame));
    
    const CGFloat reasonLabelRightMargin = 32;
    CGRect reasonFrame = (CGRect){
        .origin.x = cellMargin.left,
        .origin.y = CGRectGetMaxY(self.imageView.frame) + imageViewBottomMargin,
        .size.width = CGRectGetWidth(self.contentView.bounds) - cellMargin.left - reasonLabelRightMargin,
    };
    CGFloat cellHeight = [self.class rowHeightWithBanReason:self.reasonLabel.text
                                                      width:CGRectGetWidth(self.contentView.frame)];
    reasonFrame.size.height = cellHeight - CGRectGetMinY(reasonFrame) - cellMargin.bottom;
    self.reasonLabel.frame = reasonFrame;
    
    self.backgroundView.frame = (CGRect){ .size = self.bounds.size };
}

@end
