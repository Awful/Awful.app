//  ResourceURLProtocol.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import MobileCoreServices
import class ScannerShim.Scanner
import UIKit
import WebKit

private let Log = Logger.get()

/**
 Provides a URL scheme of the form `awful-resource://<bundle-resource-path>`, which gives convenient access to bundled images etc. from theme CSS.
 
 Automatically loads `@3x` and/or `@2x` versions of image resources when available, with priority given to scales closest to the main screen.
 
 Unlike `UIImage.imageNamed()`, the path extension is required.
 
 This class is usable with `URLProtocol.registerClass`, and instances can be used with `WKWebViewConfiguration.setURLSchemeHandler(_:forURLScheme:)`.
 
 # Examples
 
 - `awful-resource://updog.png` on an iPhone 6+ will attempt to load `updog@3x.png`, then `updog@2x.png`, then `updog.png` from the main bundle's resources folder, using the first one found.
 - `awful-resource://only-big@2x.png` will attempt to load `only-big@2x.png` from the main bundle's resources folder, regardless of main screen scale.
 */
final class ResourceURLProtocol: URLProtocol {
    
    static let scheme = "awful-resource"
    
    private func loadResource(url initialURL: URL, client: URLClientWrapper) {
        let resource = Resource(initialURL)
        do {
            let bundledURL = try findBundledURL(resource)
            let resourceData = try loadData(from: bundledURL)
            
            let response = URLResponse(url: initialURL, mimeType: resource.mimeType, expectedContentLength: resourceData.count, textEncodingName: nil)
            client.didReceive(response, in: self)
            
            client.didReceive(resourceData, in: self)
        } catch {
            Log.e("Could not load \(initialURL): \(error)")
            client.didFailWithError(error, in: self)
            return
        }
        
        client.didFinish(in: self)
    }
    
    private func findBundledURL(_ resource: Resource) throws -> URL {
        let possibleBundledURLs = resource
            .pathsForScreenWithScale(UIScreen.main.scale)
            .map { Bundle.main.url(forResource: $0, withExtension: nil) }
            .compactMap { $0 }
        
        guard let resourceURL = possibleBundledURLs.first else {
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        return resourceURL
    }
    
    private func loadData(from bundledURL: URL) throws -> Data {
        do {
            return try Data(contentsOf: bundledURL)
        } catch {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSUnderlyingErrorKey: error])
        }
    }
    
    // MARK: URLProtocol
    
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme?.lowercased() == scheme
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let client = client else { return }
        loadResource(url: request.url!, client: .foundation(client))
    }
    
    override func stopLoading() {
        // nothing to do
    }
}

@available(iOS 11.0, *)
extension ResourceURLProtocol: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        loadResource(url: task.request.url!, client: .webkit(task))
    }
    
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // nothing to do
    }
}

private struct Resource {
    let path: String
    
    init(_ resourceURL: URL) {
        // Can't really use URLComponents here since awful-resource:// URLs have annoying bits like "@2x" in images. Easier to parse ourselves.
        let scanner = Scanner(string: resourceURL.absoluteString)
        scanner.charactersToBeSkipped = nil
        _ = scanner.scanString(ResourceURLProtocol.scheme)
        _ = scanner.scanString(":")
        _ = scanner.scanString("//")
        path = String(scanner.string[scanner.currentIndex...])
    }
    
    func pathsForScreenWithScale(_ screenScale: CGFloat) -> [String] {
        guard isImage else { return [path] }
        
        let basename = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        
        // If someone asks specifically for "foo@2x.png", trying to load "foo@2x@2x.png" is probably not helpful.
        if basename.hasSuffix("@2x") || basename.hasSuffix("@3x") {
            return [path]
        }
        
        let basenameSuffixes: [String]
        switch screenScale {
        case 1:
            basenameSuffixes = ["", "@2x", "@3x"]
        case 2:
            basenameSuffixes = ["@2x", "@3x", ""]
        case 3:
            basenameSuffixes = ["@3x", "@2x", ""]
        default:
            Log.w("unexpected screen scale \(screenScale)")
            basenameSuffixes = [""]
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
    
    var mimeType: String {
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

private enum URLClientWrapper {
    case foundation(URLProtocolClient)
    
    @available(iOS 11.0, *)
    case webkit(WKURLSchemeTask)
    
    func didFailWithError(_ error: Error, in urlProtocol: URLProtocol) {
        switch self {
        case .foundation(let client):
            client.urlProtocol(urlProtocol, didFailWithError: error)
            
        case .webkit(let task):
            task.didFailWithError(error)
        }
    }
    
    func didReceive(_ response: URLResponse, in urlProtocol: URLProtocol) {
        switch self {
        case .foundation(let client):
            client.urlProtocol(urlProtocol, didReceive: response, cacheStoragePolicy: .notAllowed)
            
        case .webkit(let task):
            task.didReceive(response)
        }
    }
    
    func didReceive(_ data: Data, in urlProtocol: URLProtocol) {
        switch self {
        case .foundation(let client):
            client.urlProtocol(urlProtocol, didLoad: data)
            
        case .webkit(let task):
            task.didReceive(data)
        }
    }
    
    func didFinish(in urlProtocol: URLProtocol) {
        switch self {
        case .foundation(let client):
            client.urlProtocolDidFinishLoading(urlProtocol)
            
        case .webkit(let task):
            task.didFinish()
        }
    }
}
