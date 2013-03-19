//
//  AwfulPostIconPickerController.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "PSTCollectionView.h"
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

@end


@protocol AwfulPostIconPickerControllerDelegate <NSObject>
@required

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker;

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker
            postIconAtIndex:(NSInteger)index;

@optional

// Sent when a final icon has been chosen.
- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker;

// Sent whenever the selection changes.
- (void)postIconPicker:(AwfulPostIconPickerController *)picker
  didSelectIconAtIndex:(NSInteger)index;

// Sent when the icon selection should not occur.
- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker;

@end
