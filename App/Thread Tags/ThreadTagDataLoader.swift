//  ThreadTagDataLoader.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import MobileCoreServices
import Nuke
import os
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadTagDataLoader")

/// Teaches a Nuke `ImagePipeline` to look for thread tag images in the app bundle before fetching them from the internet.
final class ThreadTagDataLoader: DataLoading {
    
    private let bundle: Bundle
    private let fallbackLoader: DataLoading
    private let objectionableImageNames: Set<String>
    
    init(bundle: Bundle, objectionableImageNames: Set<String>, fallback: DataLoading) {
        self.bundle = bundle
        fallbackLoader = fallback
        self.objectionableImageNames = objectionableImageNames
    }
    
    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping (Data, URLResponse) -> Void,
        completion: @escaping (Swift.Error?) -> Void)
        -> Nuke.Cancellable
    {
        logger.debug("loading \(request)")
        
        let targetURL = request.url!
        
        let imageName = targetURL.deletingPathExtension().lastPathComponent
        if objectionableImageNames.contains(imageName) {
            completion(Error.potentionallyObjectionableImageName)
            return Progress()
        }
        
        // grab last path component, check Thread Tags
        guard
            let bundleURL = bundle.url(forResource: targetURL.lastPathComponent, withExtension: nil, subdirectory: "Thread Tags") else
        {
            logger.debug("\(request) is not bundled, will look elsewhere")
            return fallbackLoader.loadData(with: request, didReceiveData: didReceiveData, completion: completion)
        }
        
        let data: Data
        do {
            try data = Data(contentsOf: bundleURL)
        } catch {
            logger.warning("could not load bundled thread tag data from \(bundleURL), will look elsewhere: \(error)")
            return fallbackLoader.loadData(with: request, didReceiveData: didReceiveData, completion: completion)
        }
        
        logger.debug("\(targetURL) is bundled, returning image data directly")
        
        let mimeType = UTType.png.preferredMIMEType!
        let response = HTTPURLResponse(url: targetURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Length": "\(data.count)",
            "Content-Type": mimeType,
            "Cache-Control": "no-cache, no-store, must-revalidate", // skip Nuke's disk cache
            ])!
        didReceiveData(data, response)
        completion(nil)
        
        return Progress()
    }
    
    enum Error: Swift.Error {
        case potentionallyObjectionableImageName
    }
}

extension Progress: Nuke.Cancellable {}
