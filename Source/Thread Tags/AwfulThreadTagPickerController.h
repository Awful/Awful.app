//  AwfulThreadTagPickerController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulViewController.h"
@protocol AwfulThreadTagPickerControllerDelegate;

/**
 * An AwfulThreadTagPickerController is used to choose a thread tag (and maybe a secondary thread tag too) from a list of choices.
 */
@interface AwfulThreadTagPickerController : AwfulCollectionViewController

- (instancetype)initWithImageNames:(NSArray *)imageNames secondaryImageNames:(NSArray *)secondaryImageNames NS_DESIGNATED_INITIALIZER;

/**
 * An array of NSString instances representing the imageNames of the thread tags to choose from.
 */
@property (readonly, copy, nonatomic) NSArray *imageNames;

/**
 * An array of NSString instances representing the imageNames of the secondary thread tags to choose from.
 */
@property (readonly, copy, nonatomic) NSArray *secondaryImageNames;

/**
 * Shows a thread tag picker from a particular view. On iPhone, the picker is presented modally and the view is not used. On iPad, a popover is shown pointing to the view.
 */
- (void)presentFromView:(UIView *)view;

/**
 * Removes the picker from view.
 */
- (void)dismiss;

/**
 * Selects a particular thread tag. Any previous selection is removed. No messages are sent to the delegate as a result of calling this method.
 */
- (void)selectImageName:(NSString *)imageName;

/**
 * Selects a particular secondary thread tag. Any previous selection is removed. No messages are sent to the delegate as a result of calling this method.
 */
- (void)selectSecondaryImageName:(NSString *)imageName;

/**
 * A button item that, when tapped, dismisses the picker.
 */
@property (readonly, strong, nonatomic) UIBarButtonItem *cancelButtonItem;

/**
 * A button item that, when tapped, dismisses the picker.
 */
@property (readonly, strong, nonatomic) UIBarButtonItem *doneButtonItem;

@property (weak, nonatomic) id <AwfulThreadTagPickerControllerDelegate> delegate;

@end

@protocol AwfulThreadTagPickerControllerDelegate <NSObject>

/**
 * Sent when the selected thread tag has changed.
 */
@required
- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectImageName:(NSString *)imageName;

/**
 * Sent when the selected secondary thread tag has changed. The delegate must implement this method if it provides secondaryImageNames to the initializer.
 */
@optional
- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectSecondaryImageName:(NSString *)secondaryImageName;

/**
 * Sent when the picker is dismissed by tapping the doneButtonItem, cancelButtonItem, or tapping away from the popover.
 */
@optional
- (void)threadTagPickerDidDismiss:(AwfulThreadTagPickerController *)picker;

@end
