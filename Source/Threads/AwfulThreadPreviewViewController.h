//  AwfulThreadPreviewViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "PostPreviewViewController.h"
@class Forum, ThreadTag;

@interface AwfulThreadPreviewViewController : PostPreviewViewController

- (instancetype)initWithForum:(Forum *)forum
                      subject:(NSString *)subject
                    threadTag:(ThreadTag *)threadTag
           secondaryThreadTag:(ThreadTag *)secondaryThreadTag
                       BBcode:(NSAttributedString *)BBcode NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) Forum *forum;
@property (readonly, copy, nonatomic) NSString *subject;
@property (readonly, strong, nonatomic) ThreadTag *threadTag;
@property (readonly, strong, nonatomic) ThreadTag *secondaryThreadTag;
@property (readonly, copy, nonatomic) NSAttributedString *BBcode;

@end
