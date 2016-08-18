//  UploadImageAttachments.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import ImgurAnonymousAPIClient
import Photos

/**
    Replaces image attachments in richText with [img] tags by uploading the images anonymously to Imgur.
 
    - parameter completion: A block to call on the main queue after replacement, which gets as arguments: the tagged string on success, or nil on failure; and an error on failure, or nil on success.
 
    - returns: A progress object that can cancel the image upload.
 */
func uploadImages(attachedTo richText: NSAttributedString, completion: (_ plainText: String?, _ error: NSError?) -> Void) -> NSProgress {
    let progress = NSProgress(totalUnitCount: 1)
    
    let localCopy = richText.mutableCopy() as! NSMutableAttributedString
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { 
        let tags = localCopy.imageTags
        guard !tags.isEmpty else {
            progress.completedUnitCount += 1
            return dispatch_async(dispatch_get_main_queue()) {
                completion(plainText: localCopy.string, error: nil)
            }
        }
        
        let uploadProgress = uploadImages(fromSources: tags.map { $0.source }, completion: { (urls, error) in
            if let error = error {
                return dispatch_async(dispatch_get_main_queue()) {
                    completion(plainText: nil, error: error)
                }
            }
            
            guard let urls = urls else { fatalError("no error should mean some URLs!") }
            for (url, tag) in zip(urls, tags).reverse() {
                localCopy.replaceCharactersInRange(tag.range, withString: tag.BBcode(url))
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(plainText: localCopy.string, error: nil)
            }
        })
        progress.addChild(uploadProgress, withPendingUnitCount: 1)
    }
    
    return progress
}

private func uploadImages(fromSources sources: [ImageTag.Source], completion: (_ urls: [NSURL]?, _ error: NSError?) -> Void) -> NSProgress {
    let progress = NSProgress(totalUnitCount: Int64(sources.count))
    
    let group = dispatch_group_create()
    
    var urls: [NSURL!] = Array(count: sources.count, repeatedValue: nil)
    for (i, source) in sources.enumerate() {
        dispatch_group_enter(group)
        
        func uploadComplete(url: NSURL?, error: NSError?) {
            defer { dispatch_group_leave(group) }
            
            if let error = error {
                if !progress.cancelled { progress.cancel() }
                return dispatch_async(dispatch_get_main_queue()) {
                    completion(urls: nil, error: error)
                }
            }
            
            guard let url = url else { fatalError("no error should mean a URL!") }
            urls[i] = url
        }
        
        progress.becomeCurrentWithPendingUnitCount(1)
        
        switch source {
        case .Asset(let assetURL):
            ImgurAnonymousAPIClient.sharedClient().uploadAssetWithURL(assetURL, filename: "image.png", completionHandler: uploadComplete)
        case .Image(let image):
            ImgurAnonymousAPIClient.sharedClient().uploadImage(image, withFilename: "image.png", completionHandler: uploadComplete)
        }
        
        progress.resignCurrent()
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { 
        if progress.cancelled {
            completion(urls: nil, error: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
        } else {
            completion(urls: urls.map { $0 }, error: nil)
        }
    }
    
    return progress
}

private struct ImageTag {
    let range: NSRange
    let size: CGSize
    let source: Source
    
    enum Source {
        case Asset(NSURL)
        case Image(UIImage)
    }
    
    init(_ attachment: TextAttachment, range: NSRange) {
        self.range = range
        
        if let
            assetURL = attachment.assetURL,
            let asset = PHAsset.fetchAssetsWithALAssetURLs([assetURL], options: nil).firstObject as? PHAsset
        {
            source = .Asset(assetURL)
            size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        } else if let image = attachment.image {
            source = .Image(image)
            size = image.size
        } else {
            fatalError("couldn't get image off of attachment")
        }
    }
    
    func BBcode(url: NSURL) -> String {
        let t: String
        if
            size.width > TextAttachment.requiresThumbnailImageSize.width ||
            size.height > TextAttachment.requiresThumbnailImageSize.height
        {
            t = "t"
        } else {
            t = ""
        }
        return "[\(t)img]\(url.absoluteString)[/\(t)img]"
    }
}

private extension NSAttributedString {
    var imageTags: [ImageTag] {
        var tags: [ImageTag] = []
        enumerateAttribute(NSAttachmentAttributeName, inRange: NSRange(location: 0, length: length), options: .LongestEffectiveRangeNotRequired) { (attachment, range, stop) in
            guard let attachment = attachment as? TextAttachment else { return }
            tags.append(ImageTag(attachment, range: range))
        }
        return tags
    }
}
