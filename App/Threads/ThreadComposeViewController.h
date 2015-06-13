//  ThreadComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextViewController.h"
@import AwfulCore;

/**
 * A ThreadComposeViewController is for writing the OP of a new thread.
 */
@interface ThreadComposeViewController : ComposeTextViewController

/**
 * @param forum The forum in which the new thread is posted.
 */
- (instancetype)initWithForum:(Forum *)forum NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) Forum *forum;

/**
 * Returns the newly-posted thread.
 */
@property (readonly, strong, nonatomic) Thread *thread;

@end
