//
//  ViewController.h
//  CSS Tweaker
//
//  Created by Nolan Waite on 2013-03-15.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (void)toggleDarkMode;

- (void)loadStylesheetNamed:(NSString *)filename;

@end
