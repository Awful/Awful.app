//  AwfulTextAttachment.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/// Negotiates reasonable image bounds with its text view, provides the image property even after restoring from state, and uses the AssetsLibrary for thumbnailing when possible.
@interface AwfulTextAttachment : NSTextAttachment

- (instancetype)initWithImage:(UIImage *)image assetURL:(NSURL *)assetURL NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

/// If the text attachment's image came from the Assets Library, this URL represents the asset.
@property (strong, nonatomic) NSURL *assetURL;

/// An actually resized thumbnail of the text attachment's image (i.e. it won't make a UITextView nigh-unscrollable).
@property (readonly, strong, nonatomic) UIImage *thumbnailImage;

@end

/**
 Whether an image of the given size should be thumbnailed.
 
 "Keep all images smaller than 800 pixels horizontal and 600 pixels vertical."
 – http://www.somethingawful.com/d/forum-rules/forum-rules.php?page=2
 */
extern BOOL ImageSizeRequiresThumbnailing(CGSize imageSize);
