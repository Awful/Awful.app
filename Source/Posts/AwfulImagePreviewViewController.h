//
//  AwfulImagePreviewViewController.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulImagePreviewViewController : UIViewController

- (id)initWithURL:(NSURL *)imageURL;

@property (nonatomic) NSURL *imageURL;

@end
