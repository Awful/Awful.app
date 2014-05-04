//  AwfulNewPrivateMessageFieldView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewPrivateMessageFieldView.h"

@implementation AwfulNewPrivateMessageFieldView
{
    UIView *_topSeparator;
    UIView *_bottomSeparator;
}

@synthesize enabled = _enabled;

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _threadTagButton = [AwfulThreadTagButton new];
    _threadTagButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_threadTagButton];
    
    _toField = [AwfulComposeField new];
    _toField.translatesAutoresizingMaskIntoConstraints = NO;
    _toField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _toField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self addSubview:_toField];
    
    _topSeparator = [UIView new];
    _topSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    _topSeparator.backgroundColor = [UIColor lightGrayColor];
    [self addSubview:_topSeparator];
    
    _subjectField = [AwfulComposeField new];
    _subjectField.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_subjectField];
    
    _bottomSeparator = [UIView new];
    _bottomSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomSeparator.backgroundColor = [UIColor lightGrayColor];
    [self addSubview:_bottomSeparator];
    
    NSDictionary *views = @{ @"tag": _threadTagButton,
                             @"to": _toField,
                             @"topSeparator": _topSeparator,
                             @"subject": _subjectField,
                             @"bottomSeparator": _bottomSeparator };
    [_threadTagButton addConstraint:
     [NSLayoutConstraint constraintWithItem:_threadTagButton
                                  attribute:NSLayoutAttributeHeight
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:_threadTagButton
                                  attribute:NSLayoutAttributeWidth
                                 multiplier:1
                                   constant:0]];
    [self addConstraint:
     [NSLayoutConstraint constraintWithItem:_threadTagButton
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self
                                  attribute:NSLayoutAttributeCenterY
                                 multiplier:1
                                   constant:0]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tag(54)][to]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[tag][topSeparator]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[tag][subject]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomSeparator]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[to(subject)][topSeparator(1)][subject(to)][bottomSeparator(1)]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    return self;
}

#pragma mark - AwfulComposeCustomView

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    self.threadTagButton.enabled = enabled;
    self.toField.textField.enabled = enabled;
    self.subjectField.textField.enabled = enabled;
}

- (UIResponder *)initialFirstResponder
{
    if (self.toField.textField.text.length == 0) {
        return self.toField.textField;
    } else if (self.subjectField.textField.text.length == 0) {
        return self.subjectField.textField;
    } else {
        return nil;
    }
}

@end
