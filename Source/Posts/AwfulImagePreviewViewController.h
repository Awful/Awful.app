//
//  AwfulImagePreviewViewController.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>

@interface AwfulImagePreviewViewController : UIViewController

- (id)initWithURL:(NSURL *)imageURL;

@property (nonatomic) NSURL *imageURL;

@end
