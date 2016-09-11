//  ResourceURLProtocol.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import MobileCoreServices
import UIKit

/**
Provides a URL scheme of the form `awful-resource://<bundle-resource-path>`, which gives convenient access to bundled images etc. from theme CSS.

Automatically loads `@3x` and/or `@2x` versions of image resources when available, and when the main screen is of sufficient scale.

Unlike `UIImage.imageNamed()`, the path extension is required.

**Examples**

- `awful-resource://updog.png` on an iPhone 6+ will attempt to load `updog@3x.png`, then `updog@2x.png`, then `updog.png` from the main bundle's resources folder, using the first one found.
- `awful-resource://only-big@2x.png` will attempt to load `only-big@2x.png` from the main bundle's resources folder, regardless of main screen scale.
*/
final class ResourceURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme?.lowercased() == scheme
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let URL = request.url!
        let resource = Resource(URL)
        
        let possibleResourceURLs = resource
            .pathsForScreenWithScale(UIScreen.main.scale)
            .map { Bundle.main.url(forResource: $0, withExtension: nil) }
            .flatMap { $0 }
        
        guard let resourceURL = possibleResourceURLs.first else {
            print("Could not find resource for URL \(URL)")
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        guard let resourceData = try? Data(contentsOf: resourceURL) else {
            let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSLocalizedDescriptionKey: "Missing file"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        let response = URLResponse(url: URL, mimeType: resource.MIMEType, expectedContentLength: resourceData.count, textEncodingName: nil)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowedInMemoryOnly)
        
        client?.urlProtocol(self, didLoad: resourceData)
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // nothing to do
    }
}

private let scheme = "awful-resource"

private struct Resource {
    let path: String
    
    init(_ resourceURL: URL) {
        // Can't really use NSURLComponents here since awful-resource:// URLs have annoying bits like "@2x" in images. Easier to parse ourselves.
        let scanner = Scanner(string: resourceURL.absoluteString)
        scanner.charactersToBeSkipped = nil
        scanner.scanString(scheme, into: nil)
        scanner.scanString(":", into: nil)
        scanner.scanString("//", into: nil)
        path = (scanner.string as NSString).substring(from: scanner.scanLocation)
    }
    
    func pathsForScreenWithScale(_ screenScale: CGFloat) -> [String] {
        guard isImage && screenScale > 1 else {
            return [path]
        }
        
        let basename = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        
        // If someone asks specifically for "foo@2x.png", trying to load "foo@2x@2x.png" is probably not helpful.
        guard !basename.hasSuffix("@2x") && !basename.hasSuffix("@3x") else {
            return [path]
        }
        
        var basenameSuffixes = [""]
        if screenScale >= 2 {
            basenameSuffixes.insert("@2x", at: 0)
        }
        if screenScale >= 3 {
            basenameSuffixes.insert("@3x", at: 0)
        }
        
        let folders = (path as NSString).deletingLastPathComponent
        let pathExtension = (path as NSString).pathExtension
        return basenameSuffixes.map { suffix in
            let filename = ("\(basename)\(suffix)" as NSString).appendingPathExtension(pathExtension)!
            return (folders as NSString).appendingPathComponent(filename)
        }
    }
    
    var isImage: Bool {
        if let UTI = UTI {
            return UTTypeConformsTo(UTI as CFString, kUTTypeImage)
        } else {
            return false
        }
    }
    
    fileprivate var UTI: String? {
        return UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (path as NSString).pathExtension as CFString, nil)?.takeRetainedValue() as String?
    }
    
    var MIMEType: String {
        if let
            UTI = UTI,
            let MIMEType = UTTypeCopyPreferredTagWithClass(UTI as CFString, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return MIMEType as String
        } else {
            return "application/octet-stream"
        }
    }
}
