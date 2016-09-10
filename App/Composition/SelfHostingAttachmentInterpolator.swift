//  SelfHostingAttachmentInterpolator.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Hosts image data via the `awful-image` URL protocol so it can be shown from a UIWebView.
final class SelfHostingAttachmentInterpolator: NSObject {
    fileprivate var URLs: [URL] = []
    
    func interpolateImagesInString(_ string: NSAttributedString) -> String {
        let basePath = UUID().uuidString as NSString
        let mutableString = string.mutableCopy() as! NSMutableAttributedString
        
        // I'm not sure how to modify the string within calls to -[NSMutableAttributedString enumerateAttribute:...] when the range has length one, unless we go in reverse. I'm not sure it's a bug either.
        string.enumerateAttribute(NSAttachmentAttributeName, in: NSRange(0..<string.length), options: [.longestEffectiveRangeNotRequired, .reverse]) { (attachment, range, stop) in
            guard let attachment = attachment as? NSTextAttachment else { return }
            let path = basePath.appendingPathComponent("\(self.URLs.count)")
            guard let URL = serve(attachment: attachment, fromPath: path) else { return }
            self.URLs.append(URL)
            
            let imageSize = attachment.image?.size ?? .zero
            let requiresThumbnailing = imageSize.width > TextAttachment.requiresThumbnailImageSize.width || imageSize.height > TextAttachment.requiresThumbnailImageSize.height
            let t = requiresThumbnailing ? "t" : ""
            // SA: The [img] BBcode seemingly only matches if the URL starts with "http[s]://" or it refuses to actually turn it into an <img> element, so we'll prefix it with http:// and then remove that later.
            let tag = "[\(t)img]http://\(URL.absoluteString)[/\(t)img]"
            let replacement = NSAttributedString(string: tag)
            mutableString.replaceCharacters(in: range, with: replacement)
        }
        
        return mutableString.string
    }
    
    deinit {
        URLs.forEach(ImageURLProtocol.stopServingImageAtURL)
    }
}

private func serve(attachment: NSTextAttachment, fromPath path: String) -> URL? {
    if let attachment = attachment as? TextAttachment {
        if let assetURL = attachment.assetURL {
            return ImageURLProtocol.serveAsset(assetURL, atPath: path)
        }
        
        if let image = attachment.thumbnailImage {
            return ImageURLProtocol.serveImage(image, atPath: path)
        }
    }
    
    guard let image = attachment.image else { return nil }
    return ImageURLProtocol.serveImage(image, atPath: path)
}
