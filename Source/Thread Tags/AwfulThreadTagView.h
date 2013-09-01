//  AwfulThreadTagView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulThreadTagView : UIView

@property (nonatomic) UIImage *tagImage;

- (void)setTagBorderColor:(UIColor *)borderColor width:(CGFloat)width;

// Occupies the top-left quadrant of the tag.
@property (nonatomic) UIImage *secondaryTagImage;

@end
