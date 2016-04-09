//  AwfulNewThreadFieldView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewThreadFieldView.h"

#import "Awful-Swift.h"

@implementation AwfulNewThreadFieldView
{
    UIView *_separator;
}

@synthesize enabled = _enabled;

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _threadTagButton = [ThreadTagButton new];
        _threadTagButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_threadTagButton];
        
        _subjectField = [ComposeField new];
        _subjectField.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_subjectField];
        
        _separator = [UIView new];
        _separator.translatesAutoresizingMaskIntoConstraints = NO;
        _separator.backgroundColor = [UIColor lightGrayColor];
        [self addSubview:_separator];
        
        NSDictionary *views = @{ @"tag": _threadTagButton,
                                 @"subject": _subjectField,
                                 @"separator": _separator };
        [_threadTagButton addConstraint:
         [NSLayoutConstraint constraintWithItem:_threadTagButton
                                      attribute:NSLayoutAttributeWidth
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:_threadTagButton
                                      attribute:NSLayoutAttributeHeight
                                     multiplier:1
                                       constant:0]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tag][subject]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tag]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[subject][separator(1)]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[separator]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
    return self;
}

#pragma mark - AwfulComposeCustomView

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    self.threadTagButton.enabled = enabled;
    self.subjectField.textField.enabled = enabled;
}

- (UIResponder *)initialFirstResponder
{
    UITextField *subject = self.subjectField.textField;
    return subject.text.length > 0 ? subject : nil;
}

@end
