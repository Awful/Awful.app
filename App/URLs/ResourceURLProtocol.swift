//  ResourceURLProtocol.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import MobileCoreServices

private let scheme = "awful-resource"

/// Provides a URL scheme of the form `awful-resource://<bundle-resource-path>`.
final class ResourceURLProtocol: NSURLProtocol {
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        return request.URL?.scheme.lowercaseString == scheme
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override func startLoading() {
        let URL = request.URL!
        
        // Can't really use NSURLComponents here since awful-resource:// URLs have annoying bits like "@2x" in images. Easier to parse ourselves.
        let scanner = NSScanner(string: URL.awful_absoluteUnicodeString())
        scanner.charactersToBeSkipped = nil
        scanner.scanString(scheme, intoString: nil)
        scanner.scanString(":", intoString: nil)
        scanner.scanString("//", intoString: nil)
        let resourcePath = (scanner.string as NSString).substringFromIndex(scanner.scanLocation)
        
        guard let resourceURL = NSBundle.mainBundle().URLForResource(resourcePath, withExtension: nil) else {
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
        
        let MIMEType: String
        if let
            pathExtension = URL.pathExtension,
            detectedMIMEType = MIMETypeForPathExtension(pathExtension)
        {
            MIMEType = detectedMIMEType
        } else {
            MIMEType = "application/octet-stream"
        }
        
        let response = NSURLResponse(URL: URL, MIMEType: MIMEType, expectedContentLength: resourceData.length, textEncodingName: nil)
        client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .AllowedInMemoryOnly)
        
        client?.URLProtocol(self, didLoadData: resourceData)
        
        client?.URLProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // nothing to do
    }
}

private func MIMETypeForPathExtension(fileExtension: String) -> String? {
    guard let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, nil)?.takeRetainedValue() else {
        return nil
    }
    
    return UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType)?.takeRetainedValue() as String?
}
