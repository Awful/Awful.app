//  AwfulPostIconPickerController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import <PSTCollectionView/PSTCollectionView.h>
@protocol AwfulPostIconPickerControllerDelegate;

@interface AwfulPostIconPickerController : PSUICollectionViewController

// Designated initializer.
- (instancetype)initWithDelegate:(id <AwfulPostIconPickerControllerDelegate>)delegate;

@property (weak, nonatomic) id <AwfulPostIconPickerControllerDelegate> delegate;

- (void)reloadData;

// Displays a post icon picker in a popover.
//
// Does nothing on iPhone. On iPhone, present the picker modally.
- (void)showFromRect:(CGRect)rect inView:(UIView *)view;

// Immediately dismiss a picker in a popover.
- (void)dismiss;

// Setting the selectedIndex does not cause any selection-related delegate methods to be called.
// If no icon is selected, returns NSNotFound.
@property (nonatomic) NSInteger selectedIndex;

// Setting the secondarySelectedIndex does not cause any secondary selection-related delegate
// methods to be called.
// If no secondary icons are selected, or none are available, returns NSNotFound.
@property (nonatomic) NSInteger secondarySelectedIndex;

@end


@protocol AwfulPostIconPickerControllerDelegate <NSObject>
@required

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker;

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker
            postIconAtIndex:(NSInteger)index;

@optional

// Secondary icons are ones like "Ask", "Tell", "Buying", or "Selling". They appear in a separate
// section atop the icons as a whole, and are shown atop the currently-selected icon.
//
// If the delegate does not implement this method, it is as if the delegate did and always returns
// 0.
- (NSInteger)numberOfSecondaryIconsInPostIconPicker:(AwfulPostIconPickerController *)picker;

// Secondary icon images occupy the top-left quadrant of the post icon.
//
// This method is not optional if the delegate implements -numberOfSecondaryIconsInPostIconPicker:
// and returns from it a number greater than 0.
- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker
       secondaryIconAtIndex:(NSInteger)index;

// Sent when a final icon has been chosen.
- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker;

// Sent whenever the selection changes.
- (void)postIconPicker:(AwfulPostIconPickerController *)picker
  didSelectIconAtIndex:(NSInteger)index;

- (void)postIconPicker:(AwfulPostIconPickerController *)picker
didSelectSecondaryIconAtIndex:(NSInteger)index;

// Sent when the icon selection should not occur.
- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker;

@end
