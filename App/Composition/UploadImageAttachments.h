//  UploadImageAttachments.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/**
 Replaces image attachments in richText with [img] tags by uploading the images to Imgur.
 
 @param completion  A block to call on the main queue after replacement, which gets as arguments: the tagged string on success, or nil on failure; and an error on failure, or nil on success.
 
 @return An NSProgress that cancel the image upload.
 */
NSProgress * UploadImageAttachments(NSAttributedString *richText, void (^completion)(NSString *plainText, NSError *error));
