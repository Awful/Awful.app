//  AwfulSelfHostingAttachmentInterpolator.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/**
 * An AwfulSelfHostingAttachmentInterpolator hosts image data using the `awful-image` protocol so it can be shown from any UIWebView.
 */
@interface AwfulSelfHostingAttachmentInterpolator : NSObject

- (NSString *)interpolateImagesInString:(NSAttributedString *)string;

@end
