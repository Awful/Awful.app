//
//  AwfulTextView.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
@protocol AwfulTextViewDelegate;

@interface AwfulTextView : UITextView

@property (weak, nonatomic) id <UITextViewDelegate, AwfulTextViewDelegate> delegate;

- (CGRect)selectedTextRect;

@end


@protocol AwfulTextViewDelegate <NSObject>
@optional

// Sent when an "insert image" menu item is chosen.
- (void)textView:(AwfulTextView *)textView
    showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType;

// Sent when a "paste image" menu item is chosen.
- (void)textView:(AwfulTextView *)textView insertImage:(UIImage *)image;

@end
