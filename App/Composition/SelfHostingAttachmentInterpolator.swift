//  SelfHostingAttachmentInterpolator.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Hosts image data via the `awful-image` URL protocol so it can be shown from a UIWebView.
final class SelfHostingAttachmentInterpolator: NSObject {
    private var URLs: [NSURL] = []
    
    func interpolateImagesInString(string: NSAttributedString) -> String {
        let basePath = NSUUID().UUIDString as NSString
        let mutableString = string.mutableCopy() as! NSMutableAttributedString
        
        // I'm not sure how to modify the string within calls to -[NSMutableAttributedString enumerateAttribute:...] when the range has length one, unless we go in reverse. I'm not sure it's a bug either.
        string.enumerateAttribute(NSAttachmentAttributeName, inRange: NSRange(0..<string.length), options: [.LongestEffectiveRangeNotRequired, .Reverse]) { (attachment, range, stop) in
            guard let attachment = attachment as? NSTextAttachment else { return }
            let path = basePath.stringByAppendingPathComponent("\(self.URLs.count)")
            let URL = serve(attachment: attachment, fromPath: path)
            self.URLs.append(URL)
            
            let imageSize = attachment.image?.size ?? .zero
            let requiresThumbnailing = imageSize.width > TextAttachment.requiresThumbnailImageSize.width || imageSize.height > TextAttachment.requiresThumbnailImageSize.height
            let t = requiresThumbnailing ? "t" : ""
            // SA: The [img] BBcode seemingly only matches if the URL starts with "http[s]://" or it refuses to actually turn it into an <img> element, so we'll prefix it with http:// and then remove that later.
            let tag = "[\(t)img]http://\(URL.absoluteString)[/\(t)img]"
            let replacement = NSAttributedString(string: tag)
            mutableString.replaceCharactersInRange(range, withAttributedString: replacement)
        }
        
        return mutableString.string
    }
    
    deinit {
        URLs.forEach(AwfulImageURLProtocol.stopServingImageAtURL)
    }
}

private func serve(attachment attachment: NSTextAttachment, fromPath path: String) -> NSURL {
    if let attachment = attachment as? TextAttachment {
        if let assetURL = attachment.assetURL {
            return AwfulImageURLProtocol.serveAsset(assetURL, atPath: path)
        }
        
        return AwfulImageURLProtocol.serveImage(attachment.thumbnailImage, atPath: path)
    }
    
    return AwfulImageURLProtocol.serveImage(attachment.image, atPath: path)
}
