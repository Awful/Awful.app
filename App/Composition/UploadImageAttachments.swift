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
func uploadImages(attachedTo richText: NSAttributedString, completion: @escaping (_ plainText: String?, _ error: Error?) -> Void) -> Progress {
    let progress = Progress(totalUnitCount: 1)
    
    let localCopy = richText.mutableCopy() as! NSMutableAttributedString
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { 
        let tags = localCopy.imageTags
        guard !tags.isEmpty else {
            progress.completedUnitCount += 1
            return DispatchQueue.main.async {
                completion(localCopy.string, nil)
            }
        }
        
        let uploadProgress = uploadImages(fromSources: tags.map { $0.source }, completion: { (urls, error) in
            if let error = error {
                return DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
            
            guard let urls = urls else { fatalError("no error should mean some URLs!") }
            for (url, tag) in zip(urls, tags).reversed() {
                localCopy.replaceCharacters(in: tag.range, with: tag.BBcode(url as URL))
            }
            DispatchQueue.main.async {
                completion(localCopy.string, nil)
            }
        })
        progress.addChild(uploadProgress, withPendingUnitCount: 1)
    }
    
    return progress
}

private func uploadImages(fromSources sources: [ImageTag.Source], completion: @escaping (_ urls: [URL]?, _ error: Error?) -> Void) -> Progress {
    let progress = Progress(totalUnitCount: Int64(sources.count))
    
    let group = DispatchGroup()
    
    var urls: [URL?] = Array(repeating: nil, count: sources.count)
    for (i, source) in sources.enumerated() {
        group.enter()
        
        func uploadComplete(_ url: URL?, error: Error?) {
            defer { group.leave() }
            
            if let error = error {
                if !progress.isCancelled { progress.cancel() }
                return DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
            
            guard let url = url else { fatalError("no error should mean a URL!") }
            urls[i] = url
        }
        
        progress.becomeCurrent(withPendingUnitCount: 1)
        
        switch source {
        case .asset(let assetURL):
            ImgurAnonymousAPIClient.shared().uploadAsset(with: assetURL, filename: "image.png", completionHandler: uploadComplete)
        case .image(let image):
            ImgurAnonymousAPIClient.shared().uploadImage(image, withFilename: "image.png", completionHandler: uploadComplete)
        }
        
        progress.resignCurrent()
    }
    
    group.notify(queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default)) { 
        if progress.isCancelled {
            completion(nil, NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
        } else {
            completion(urls.flatMap { $0 }, nil)
        }
    }
    
    return progress
}

private struct ImageTag {
    let range: NSRange
    let size: CGSize
    let source: Source
    
    enum Source {
        case asset(URL)
        case image(UIImage)
    }
    
    init(_ attachment: TextAttachment, range: NSRange) {
        self.range = range
        
        if
            let assetURL = attachment.assetURL,
            let asset = PHAsset.fetchAssets(withALAssetURLs: [assetURL as URL], options: nil).firstObject
        {
            source = .asset(assetURL)
            size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        } else if let image = attachment.image {
            source = .image(image)
            size = image.size
        } else {
            fatalError("couldn't get image off of attachment")
        }
    }
    
    func BBcode(_ url: URL) -> String {
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
        enumerateAttribute(NSAttachmentAttributeName, in: NSRange(location: 0, length: length), options: .longestEffectiveRangeNotRequired) { (attachment, range, stop) in
            guard let attachment = attachment as? TextAttachment else { return }
            tags.append(ImageTag(attachment, range: range))
        }
        return tags
    }
}
