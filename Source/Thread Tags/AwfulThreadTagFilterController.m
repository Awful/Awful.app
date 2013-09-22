//  AwfulThreadTagFilterController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTagFilterController.h"

@interface AwfulThreadTagFilterController () <UIPopoverControllerDelegate>

@property (nonatomic) UIBarButtonItem *pickButtonItem;
@property (nonatomic) UIPopoverController *popover;

@end


@implementation AwfulThreadTagFilterController

- (instancetype)initWithDelegate:(id <AwfulPostIconPickerControllerDelegate>)delegate
{
    if (self = [super initWithDelegate:delegate]) {
        self.title = @"Filter Posts";
    }
    return self;
}

- (UIBarButtonItem *)pickButtonItem
{
    if (_pickButtonItem) return _pickButtonItem;
    _pickButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Filter" style:UIBarButtonItemStyleDone
                                                      target:self action:@selector(didTapPick)];
    return _pickButtonItem;
}

@end
