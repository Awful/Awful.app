//  AwfulNewThreadFieldView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeTextViewController.h"
#import "AwfulComposeField.h"
#import "AwfulThreadTagButton.h"

@interface AwfulNewThreadFieldView : UIView <AwfulComposeCustomView>

@property (readonly, strong, nonatomic) AwfulThreadTagButton *threadTagButton;

@property (readonly, strong, nonatomic) AwfulComposeField *subjectField;

@end
