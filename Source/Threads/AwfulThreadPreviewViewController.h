//  AwfulThreadPreviewViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostPreviewViewController.h"

@interface AwfulThreadPreviewViewController : AwfulPostPreviewViewController

/**
 * Designated initializer.
 */
- (instancetype)initWithForum:(AwfulForum *)forum
                      subject:(NSString *)subject
                    threadTag:(AwfulThreadTag *)threadTag
           secondaryThreadTag:(AwfulThreadTag *)secondaryThreadTag
                       BBcode:(NSAttributedString *)BBcode;

@property (readonly, strong, nonatomic) AwfulForum *forum;
@property (readonly, copy, nonatomic) NSString *subject;
@property (readonly, strong, nonatomic) AwfulThreadTag *threadTag;
@property (readonly, strong, nonatomic) AwfulThreadTag *secondaryThreadTag;
@property (readonly, copy, nonatomic) NSAttributedString *BBcode;

@end
