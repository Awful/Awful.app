//  ImageURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos
import UIKit

/// An ImageURLProtocol implements the awful-image protocol, serving UIImage objects at arbitrary URLs.
final class ImageURLProtocol: NSURLProtocol {
    /**
        Adds an image whose data is served at the given path. The image's data will be held in memory; consider passing a thumbnail image where appropriate. If another image was being served at the path, it is replaced.
     
        - returns: An NSURL suitable for use in a UIWebView, for passing to an API based on the Foundation URL Loading System, and for passing to `+stopHostingImageAtURL:`.
     */
    class func serveImage(image: UIImage, atPath path: String) -> NSURL? {
        guard let data = UIImagePNGRepresentation(image) else { return nil }
        return serveImageData(data, atPath: path)
    }
    
    /**
        Adds an image from the asset library whose data is served at the given path. The image's data will be held in memory. If another image was being served at the path, it is replaced.
     
        - parameter assetURL: A URL representing an ALAsset.
     
        - returns: An NSURL suitable for use in a UIWebView, for passing to an API based on the Foundation URL Loading System, and for passing to `+stopHostingImageAtURL:`.
     */
    class func serveAsset(assetURL: NSURL, atPath path: String) -> NSURL? {
        guard let asset = PHAsset.fetchAssetsWithALAssetURLs([assetURL], options: nil).firstObject as? PHAsset else { return nil }
        
        var maybeData: NSData?
        let options = PHImageRequestOptions()
        options.synchronous = true
        PHImageManager.defaultManager().requestImageDataForAsset(asset, options: options) { (imageData, UTI, orientation, info) in
            maybeData = imageData
        }
        guard let data = maybeData else { return nil }
        return serveImageData(data, atPath: path)
    }
    
    /// Stops hosting a previously-hosted image and release the image's memory.
    class func stopServingImageAtURL(URL: NSURL) {
        imageDatas.removeValueForKey(URL.canonicalPath)
    }
    
    /// Equal to "awful-image".
    static var URLScheme: String {
        return "awful-image"
    }
    
    private static var imageDatas: [String: NSData] = [:]
    
    private class func serveImageData(data: NSData, atPath path: String) -> NSURL {
        ImageURLProtocol.imageDatas[path.canonicalPath] = data
        
        let components = NSURLComponents()
        components.scheme = ImageURLProtocol.URLScheme
        
        // See note on NSURL.canonicalPath
        components.path = path
        
        return components.URL!
    }
    
    // MARK: NSURLProtocol
    
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        guard request.URL?.scheme.caseInsensitiveCompare(ImageURLProtocol.URLScheme) == .OrderedSame else { return false }
        
        guard let path = request.URL?.canonicalPath else { return false }
        return ImageURLProtocol.imageDatas[path] != nil
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        let components = NSURLComponents()
        components.scheme = ImageURLProtocol.URLScheme
        components.path = request.URL?.canonicalPath
        
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest
        mutableRequest.URL = components.URL
        return mutableRequest
    }
    
    override func startLoading() {
        guard let
            URL = request.URL,
            let data = ImageURLProtocol.imageDatas[URL.canonicalPath]
            else { return }
        let headers = [
            "Content-Type": "image/png",
            "Content-Length": "\(data.length)",
        ]
        guard let response = NSHTTPURLResponse(URL: URL, statusCode: 200, HTTPVersion: "HTTP/1.1", headerFields: headers) else { return }
        
        client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
        client?.URLProtocol(self, didLoadData: data)
        client?.URLProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // nop
    }
}

private extension String {
    var canonicalPath: String {
        return lowercaseString
    }
}

private extension NSURL {
    /// - note: URLs tend to look something like "awful-image:ABC123-ABC-ABC-ABC123/0". NSURLComponents will parse everything after the colon as the "path", but NSURL refuses. For awful-image URLs, -[NSURLComponents path] is thought to be equivalent to -[NSURL resourceSpecifier].
    var canonicalPath: String {
        return resourceSpecifier.canonicalPath
    }
}
