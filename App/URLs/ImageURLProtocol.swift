//  ImageURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos
import UIKit

/// An ImageURLProtocol implements the awful-image protocol, serving UIImage objects at arbitrary URLs.
final class ImageURLProtocol: URLProtocol {
    /**
        Adds an image whose data is served at the given path. The image's data will be held in memory; consider passing a thumbnail image where appropriate. If another image was being served at the path, it is replaced.
     
        - returns: An NSURL suitable for use in a UIWebView, for passing to an API based on the Foundation URL Loading System, and for passing to `+stopHostingImageAtURL:`.
     */
    class func serveImage(_ image: UIImage, atPath path: String) -> URL? {
        guard let data = UIImagePNGRepresentation(image) else { return nil }
        return serveImageData(data, atPath: path)
    }
    
    /**
        Adds an image from the asset library whose data is served at the given path. The image's data will be held in memory. If another image was being served at the path, it is replaced.
     
        - parameter assetURL: A URL representing an ALAsset.
     
        - returns: An NSURL suitable for use in a UIWebView, for passing to an API based on the Foundation URL Loading System, and for passing to `+stopHostingImageAtURL:`.
     */
    class func serveAsset(_ assetURL: URL, atPath path: String) -> URL? {
        guard let asset = PHAsset.fetchAssets(withALAssetURLs: [assetURL], options: nil).firstObject else { return nil }
        
        var maybeData: Data?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        PHImageManager.default().requestImageData(for: asset, options: options) { (imageData, UTI, orientation, info) in
            maybeData = imageData
        }
        guard let data = maybeData else { return nil }
        return serveImageData(data, atPath: path)
    }
    
    /// Stops hosting a previously-hosted image and release the image's memory.
    class func stopServingImageAtURL(_ URL: Foundation.URL) {
        imageDatas.removeValue(forKey: URL.canonicalPath)
    }
    
    /// Equal to "awful-image".
    static var URLScheme: String {
        return "awful-image"
    }
    
    fileprivate static var imageDatas: [String: Data] = [:]
    
    fileprivate class func serveImageData(_ data: Data, atPath path: String) -> URL {
        ImageURLProtocol.imageDatas[path.canonicalPath] = data
        
        var components = URLComponents()
        components.scheme = ImageURLProtocol.URLScheme
        
        // See note on NSURL.canonicalPath
        components.path = path
        
        return components.url!
    }
    
    // MARK: NSURLProtocol
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard request.url?.scheme?.caseInsensitiveCompare(ImageURLProtocol.URLScheme) == .orderedSame else { return false }
        
        guard let path = request.url?.canonicalPath else { return false }
        return ImageURLProtocol.imageDatas[path] != nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        var components = URLComponents()
        components.scheme = ImageURLProtocol.URLScheme
        components.path = (request.url?.canonicalPath)!
        
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        mutableRequest.url = components.url
        return mutableRequest as URLRequest
    }
    
    override func startLoading() {
        guard let
            URL = request.url,
            let data = ImageURLProtocol.imageDatas[URL.canonicalPath]
            else { return }
        let headers = [
            "Content-Type": "image/png",
            "Content-Length": "\(data.count)",
        ]
        guard let response = HTTPURLResponse(url: URL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // nop
    }
}

private extension String {
    var canonicalPath: String {
        return lowercased()
    }
}

private extension URL {
    /// - note: URLs tend to look something like "awful-image:ABC123-ABC-ABC-ABC123/0". NSURLComponents will parse everything after the colon as the "path", but NSURL refuses. For awful-image URLs, -[NSURLComponents path] is thought to be equivalent to -[NSURL resourceSpecifier].
    var canonicalPath: String {
        return URLComponents(url: self, resolvingAgainstBaseURL: true)!.path.canonicalPath
    }
}
