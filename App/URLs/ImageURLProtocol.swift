//  ImageURLProtocol.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MobileCoreServices
import Photos
import UIKit
import WebKit

/**
 An ImageURLProtocol handles URLs with the `awful-image` scheme, serving image assets and `UIImage` objects at arbitrary, caller-chosen URLs.
 
 There's a global mapping of images to paths, and all mapped images are available anywhere the protocol is registered. `ImageURLProtocol` can be used in a web view and/or the Foundation URL Loading System; be sure to register with `URLProtocol.registerClass(_:)` and/or `WKWebViewConfiguration.setURLSchemeHandler(_:forURLScheme:)`.
 
 To make an image available using the `awful-image`, see the `ImageURLProtocol.serveImage(_:atPath:)` and `ImageURLProtocol.serveAsset(_:atPath:)` methods. Remember to call `ImageURLProtocol.stopServingImageAtURL(_:)` when you're done; image data is kept in memory while the image is available. And remember that it's a single global namespace for all mapped images; consider using random, unique identifiers (e.g. UUIDs) to avoid collisions.
 
 (Why a global mapping? Instances of URL protocols are created by the Foundation URL Loading System, so it's difficult to pass information along to any particular instance.)
 */
final class ImageURLProtocol: URLProtocol {
    
    /**
     Adds an image whose data is served at the given path. The image's data will be held in memory; consider passing a thumbnail image where appropriate. If another image was being served at the path, it is replaced.
     
     - Returns: A URL suitable for use in a web view and/or the Foundation URL Loading System (be sure to register with `URLProtocol.registerClass(_:)` and/or `WKWebViewConfiguration.setURLSchemeHandler(_:forURLScheme:)`); and for passing to `+stopHostingImageAtURL:`.
     
     - Warning: Be sure to call `stopServingImageAtURL(_:)` when you no longer need the image to be served, or you will leak memory!
     */
    class func serveImage(_ image: UIImage, atPath path: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        return serveImageData(data, atPath: path)
    }
    
    /**
     Adds an image from the asset library whose data is served at the given path. The image's data will be held in memory. If another image was being served at the path, it is replaced.
     
     - Parameter assetIdentifier: A local object identifier representing a `PHAsset`.
     
     - Returns: A `URL` suitable for use in a `UIWebView` or `WKWebView`, for passing to an API that uses the Foundation URL Loading System, and for passing to `+stopHostingImageAtURL:`.
     
     - Warning: Be sure to call `stopServingImageAtURL(_:)` when you no longer need the image to be served, or you will leak memory!
     */
    class func serveAsset(_ assetIdentifier: String, atPath path: String) -> URL? {
        guard let asset = PHAsset.firstAsset(identifiedBy: assetIdentifier) else { return nil }
        
        var maybeData: Data?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.version = .current

        let resultHandler = { (imageData: Data?, uti: String?, orientation: Any, info: [AnyHashable: Any]?) in
            maybeData = imageData
        }
        #if targetEnvironment(macCatalyst)
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options, resultHandler: resultHandler)
        #else
        PHImageManager.default().requestImageData(for: asset, options: options, resultHandler: resultHandler)
        #endif

        guard let data = maybeData, !data.isEmpty else { return nil }
        return serveImageData(data, atPath: path)
    }
    
    /// Stops hosting a previously-hosted image and release the image's memory.
    class func stopServingImageAtURL(_ URL: URL) {
        imageDatas.removeValue(forKey: URL.canonicalPath)
    }
    
    /// The URL scheme where all mapped images are made available.
    static let scheme = "awful-image"
    
    private static var imageDatas: [String: Data] = [:]
    
    private class func serveImageData(_ data: Data, atPath path: String) -> URL {
        ImageURLProtocol.imageDatas[path.canonicalPath] = data
        
        var components = URLComponents()
        components.scheme = ImageURLProtocol.scheme
        components.host = ""
        components.path = path
        
        return components.url!
    }
    
    private func loadImage(_ request: URLRequest) -> (response: HTTPURLResponse, data: Data)? {
        guard
            let url = request.url,
            let data = ImageURLProtocol.imageDatas[url.canonicalPath]
            else { return nil }
        
        let mimeType = UTTypeCopyPreferredTagWithClass(kUTTypePNG, kUTTagClassMIMEType)!.takeRetainedValue() as String
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": mimeType,
            "Content-Length": "\(data.count)"])!
        return (response: response, data: data)
    }
    
    // MARK: NSURLProtocol
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard request.url?.scheme?.caseInsensitiveCompare(ImageURLProtocol.scheme) == .orderedSame else { return false }
        
        guard let path = request.url?.canonicalPath else { return false }
        return ImageURLProtocol.imageDatas[path] != nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        var request = request
        request.url = {
            var components = URLComponents()
            components.scheme = ImageURLProtocol.scheme
            components.path = request.url!.canonicalPath
            return components.url
        }()
        return request
    }
    
    override func startLoading() {
        guard let (response, data) = loadImage(request) else {
            client?.urlProtocol(self, didFailWithError: CocoaError(.fileNoSuchFile))
            return
        }
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // nop
    }
}

extension ImageURLProtocol: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let (response, data) = loadImage(task.request) else {
            let error = CocoaError(.fileNoSuchFile)
            task.didFailWithError(error)
            return
        }
        
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }
    
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // nop
    }
}

private extension String {
    var canonicalPath: String {
        return lowercased()
    }
}

private extension URL {
    var canonicalPath: String {
        return URLComponents(url: self, resolvingAgainstBaseURL: true)!.path.canonicalPath
    }
}
