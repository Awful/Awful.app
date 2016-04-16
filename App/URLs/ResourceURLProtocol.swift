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
final class ResourceURLProtocol: NSURLProtocol {
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        return request.URL?.scheme.lowercaseString == scheme
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override func startLoading() {
        let URL = request.URL!
        let resource = Resource(URL)
        
        let possibleResourceURLs = resource
            .pathsForScreenWithScale(UIScreen.mainScreen().scale)
            .map { NSBundle.mainBundle().URLForResource($0, withExtension: nil) }
            .flatMap { $0 }
        
        guard let resourceURL = possibleResourceURLs.first else {
            print("Could not find resource for URL \(URL)")
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            client?.URLProtocol(self, didFailWithError: error)
            return
        }
        
        guard let resourceData = NSData(contentsOfURL: resourceURL) else {
            let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSLocalizedDescriptionKey: "Missing file"])
            client?.URLProtocol(self, didFailWithError: error)
            return
        }
        
        let response = NSURLResponse(URL: URL, MIMEType: resource.MIMEType, expectedContentLength: resourceData.length, textEncodingName: nil)
        client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .AllowedInMemoryOnly)
        
        client?.URLProtocol(self, didLoadData: resourceData)
        
        client?.URLProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // nothing to do
    }
}

private let scheme = "awful-resource"

private struct Resource {
    let path: String
    
    init(_ resourceURL: NSURL) {
        // Can't really use NSURLComponents here since awful-resource:// URLs have annoying bits like "@2x" in images. Easier to parse ourselves.
        let scanner = NSScanner(string: resourceURL.absoluteString)
        scanner.charactersToBeSkipped = nil
        scanner.scanString(scheme, intoString: nil)
        scanner.scanString(":", intoString: nil)
        scanner.scanString("//", intoString: nil)
        path = (scanner.string as NSString).substringFromIndex(scanner.scanLocation)
    }
    
    func pathsForScreenWithScale(screenScale: CGFloat) -> [String] {
        guard isImage && screenScale > 1 else {
            return [path]
        }
        
        let basename = ((path as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
        
        // If someone asks specifically for "foo@2x.png", trying to load "foo@2x@2x.png" is probably not helpful.
        guard !basename.hasSuffix("@2x") && !basename.hasSuffix("@3x") else {
            return [path]
        }
        
        var basenameSuffixes = [""]
        if screenScale >= 2 {
            basenameSuffixes.insert("@2x", atIndex: 0)
        }
        if screenScale >= 3 {
            basenameSuffixes.insert("@3x", atIndex: 0)
        }
        
        let folders = (path as NSString).stringByDeletingLastPathComponent
        let pathExtension = (path as NSString).pathExtension
        return basenameSuffixes.map { suffix in
            let filename = ("\(basename)\(suffix)" as NSString).stringByAppendingPathExtension(pathExtension)!
            return (folders as NSString).stringByAppendingPathComponent(filename)
        }
    }
    
    var isImage: Bool {
        if let UTI = UTI {
            return UTTypeConformsTo(UTI, kUTTypeImage)
        } else {
            return false
        }
    }
    
    private var UTI: String? {
        return UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (path as NSString).pathExtension, nil)?.takeRetainedValue() as String?
    }
    
    var MIMEType: String {
        if let
            UTI = UTI,
            MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return MIMEType as String
        } else {
            return "application/octet-stream"
        }
    }
}
