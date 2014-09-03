//  AwfulImagePreviewViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

@interface AwfulImagePreviewViewController : AwfulViewController

- (id)initWithURL:(NSURL *)imageURL;

@property (nonatomic) NSURL *imageURL;

@end

/**
 * An ImagePreviewActivity presents image URLs in an AwfulImagePreviewViewController.
 *
 * @note An ImagePreviewActivity shows the *last* URL passed to it.
 */
@interface ImagePreviewActivity : UIActivity

@end
