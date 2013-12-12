//  AwfulThreadTagView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulThreadTagView : UIView

@property (strong, nonatomic) UIImage *tagImage;

- (void)setTagBorderColor:(UIColor *)borderColor width:(CGFloat)width;

// Overlays the bottom-right corner of the tag.
@property (strong, nonatomic) UIImage *secondaryTagImage;

@end
