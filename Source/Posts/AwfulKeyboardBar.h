//
//  AwfulKeyboardBar.h
//  Awful
//
//  Created by Nolan Waite on 2013-01-17.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulKeyboardBar : UIView <UIInputViewAudioFeedback>

@property (copy, nonatomic) NSArray *characters;

@property (weak, nonatomic) id <UIKeyInput> keyInputView;

@end
