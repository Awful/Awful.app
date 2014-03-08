//  AwfulJumpToPageView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

/**
 * Implements the views of an AwfulJumpToPageController.
 */
@interface AwfulJumpToPageView : UIView

@property (readonly, strong, nonatomic) UIButton *firstPageButton;

@property (readonly, strong, nonatomic) UIButton *jumpButton;

@property (readonly, strong, nonatomic) UIButton *lastPageButton;

@property (strong, nonatomic) UIColor *buttonRowBackgroundColor;

@property (readonly, strong, nonatomic) UIPickerView *pickerView;

@end
