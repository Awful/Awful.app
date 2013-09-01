//  AwfulImagePreviewViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface AwfulImagePreviewViewController : UIViewController

- (id)initWithURL:(NSURL *)imageURL;

@property (nonatomic) NSURL *imageURL;

@end
