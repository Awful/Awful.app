//  AwfulSingleUserThreadInfo.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"

/**
 * An AwfulSingleUserThreadInfo object tracks the number of pages of posts a single author has written in a single thread, if each page has 40 posts.
 */
@interface AwfulSingleUserThreadInfo : AwfulManagedObject

/**
 * The number of pages of posts written by the author in the thread.
 */
@property (assign, nonatomic) int32_t numberOfPages;

/**
 * The author.
 */
@property (strong, nonatomic) AwfulUser *author;

/**
 * The thread.
 */
@property (strong, nonatomic) AwfulThread *thread;

@end
