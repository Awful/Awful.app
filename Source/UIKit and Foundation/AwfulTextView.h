//
//  AwfulTextView.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
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
