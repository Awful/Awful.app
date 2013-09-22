//
//  AwfulURLActionSheet.h
//  Awful
//
//  Created by simon.frost on 22/09/2013.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulActionSheet.h"

@interface AwfulURLActionSheet : AwfulActionSheet

@property (nonatomic) NSURL *url;

- (void) addSafariButton;
- (void) addExternalBrowserButtons;
- (void) addReadLaterButtons;
- (void) addCopyURLButton;

@end
