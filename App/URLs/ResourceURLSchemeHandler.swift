//  ResourceURLSchemeHandler.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import UIKit
import UniformTypeIdentifiers
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ResourceURLSchemeHandler")

/**
 Provides a URL scheme of the form `awful-resource://<bundle-resource-path>` to web views, which gives convenient access to bundled images etc. from theme CSS.

 Automatically loads `@3x` and/or `@2x` versions of image resources when available, with priority given to scales closest to the requesting web view's display scale.

 Unlike `UIImage.imageNamed()`, the path extension is required.

 # Examples

 - `awful-resource://updog.png` in a web view on a 3x display will attempt to load `updog@3x.png`, then `updog@2x.png`, then `updog.png` from the main bundle's resources folder, using the first one found.
 - `awful-resource://only-big@2x.png` will attempt to load `only-big@2x.png` from the main bundle's resources folder, whatever the display scale.
 */
final class ResourceURLSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "awful-resource"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let initialURL = task.request.url!
        let resource = Resource(initialURL)
        do {
            let bundledURL = try findBundledURL(resource, displayScale: webView.traitCollection.displayScale)
            let resourceData = try loadData(from: bundledURL)
            task.didReceive(URLResponse(url: initialURL, mimeType: resource.mimeType, expectedContentLength: resourceData.count, textEncodingName: nil))
            task.didReceive(resourceData)
        } catch {
            logger.error("Could not load \(initialURL): \(error)")
            task.didFailWithError(error)
            return
        }
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        // nothing to do
    }

    private func findBundledURL(_ resource: Resource, displayScale: CGFloat) throws -> URL {
        let possibleBundledURLs = resource
            .paths(forDisplayScale: displayScale)
            .compactMap { Bundle.main.url(forResource: $0, withExtension: nil) }

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
}

private struct Resource {
    let path: String

    init(_ resourceURL: URL) {
        // Can't really use URLComponents here since awful-resource:// URLs have annoying bits like "@2x" in images. Easier to parse ourselves.
        let scanner = Scanner(string: resourceURL.absoluteString)
        scanner.charactersToBeSkipped = nil
        _ = scanner.scanString(ResourceURLSchemeHandler.scheme)
        _ = scanner.scanString(":")
        _ = scanner.scanString("//")
        path = String(scanner.string[scanner.currentIndex...])
    }

    func paths(forDisplayScale displayScale: CGFloat) -> [String] {
        guard isImage else { return [path] }

        let basename = ((path as NSString).lastPathComponent as NSString).deletingPathExtension

        // If someone asks specifically for "foo@2x.png", trying to load "foo@2x@2x.png" is probably not helpful.
        if basename.hasSuffix("@2x") || basename.hasSuffix("@3x") {
            return [path]
        }

        let basenameSuffixes: [String]
        switch displayScale {
        case 1:
            basenameSuffixes = ["", "@2x", "@3x"]
        case 2:
            basenameSuffixes = ["@2x", "@3x", ""]
        default:
            // 3x, or a web view outside a window, which reports a display scale of 0.
            basenameSuffixes = ["@3x", "@2x", ""]
        }

        let folders = (path as NSString).deletingLastPathComponent
        let pathExtension = (path as NSString).pathExtension
        return basenameSuffixes.map { suffix in
            let filename = ("\(basename)\(suffix)" as NSString).appendingPathExtension(pathExtension)!
            return (folders as NSString).appendingPathComponent(filename)
        }
    }

    var isImage: Bool {
        uti?.conforms(to: .image) ?? false
    }

    private var uti: UTType? {
        UTType(filenameExtension: (path as NSString).pathExtension)
    }

    var mimeType: String {
        uti?.preferredMIMEType ?? "application/octet-stream"
    }
}
