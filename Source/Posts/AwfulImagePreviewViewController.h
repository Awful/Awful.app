//  AwfulImagePreviewViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

@interface AwfulImagePreviewViewController : AwfulViewController

- (id)initWithURL:(NSURL *)imageURL;

@property (nonatomic) NSURL *imageURL;

@end
