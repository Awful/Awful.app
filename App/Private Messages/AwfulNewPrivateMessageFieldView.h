//  AwfulNewPrivateMessageFieldView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextViewController.h"
#import "AwfulThreadTagButton.h"
@class ComposeField;

@interface AwfulNewPrivateMessageFieldView : UIView <AwfulComposeCustomView>

@property (readonly, strong, nonatomic) AwfulThreadTagButton *threadTagButton;

@property (readonly, strong, nonatomic) ComposeField *toField;

@property (readonly, strong, nonatomic) ComposeField *subjectField;

@end
