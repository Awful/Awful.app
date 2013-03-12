//
//  AwfulThemingViewController.h
//  Awful
//
//  Created by Nolan Waite on 2013-03-08.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AwfulThemingViewController <NSObject>

// Feel free to call super if the superclass implements this protocol.
// The topmost class in a hierarchy that implements this protocol should send -retheme in
// -viewDidLoad or similar; subclasses should not, so work is not repeated.
- (void)retheme;

@end
