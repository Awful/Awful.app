//  AwfulTextAttachment.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/**
 * An AwfulTextAttachment negotiates reasonable image bounds and provides the image property even after restoring from state.
 */
@interface AwfulTextAttachment : NSTextAttachment

/**
 * If the text attachment's image came from the Assets Library, this URL represents the asset.
 */
@property (strong, nonatomic) NSURL *assetURL;

/**
 * A thumbnail of the text attachment's image that won't turn a UITextView nigh-unscrollable.
 */
@property (readonly, strong, nonatomic) UIImage *thumbnailImage;

@end
