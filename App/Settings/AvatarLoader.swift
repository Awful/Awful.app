//  AvatarLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import FLAnimatedImage
import ImageIO
import MobileCoreServices
import PromiseKit
import UIKit

private let Log = Logger.get(level: .debug)

/// Fetches and caches avatar images.
final class AvatarLoader {
    static let shared = AvatarLoader(cacheFolder: defaultCacheFolder())
    
    private let cacheFolder: URL
    private let session = URLSession(configuration: .ephemeral)
    
    private init(cacheFolder: URL) {
        self.cacheFolder = cacheFolder
    }
    
    /// - returns: Either a UIImage or FLAnimatedImage if a cached avatar exists, otherwise nil.
    func cachedAvatarImageForUser(_ user: User) -> Any? {
        let URL = imageURLForUser(user)
        return loadImageAtFileURL(URL)
    }
    
    /// - parameter completionBlock: A block that takes: `modified` which is `true` iff the image changed; `image`, either an FLAnimatedImage or a UIImage or nil; `error`, an NSError if an error occurred.
    func fetchAvatarImageForUser(_ user: User, completionBlock: @escaping (_ modified: Bool, _ image: Any?, _ error: Error?) -> Void) {
        guard let avatarURL = user.avatarURL, !avatarURL.path.isEmpty else {
            return completionBlock(true, nil, nil)
        }

        do {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Log.e("could not create avatar cache folder \(cacheFolder): \(error)")
            return completionBlock(true, nil, nil)
        }

        var request = URLRequest(url: avatarURL)
        
        if
            let oldResponse = NSKeyedUnarchiver.unarchiveObject(withFile: cachedResponesURLForUser(user).path) as? HTTPURLResponse,
            oldResponse.url == avatarURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }

        session.downloadTask(.promise, with: request, to: imageURLForUser(user), replacingIfNecessary: true)
            .done { saveLocation, response in
                if let http = response as? HTTPURLResponse {
                    switch http.statusCode {
                    case 304:
                        return completionBlock(false, nil, nil)

                    case 200..<300:
                        Log.d("got a new avatar for user \(user.userID)")

                    case let code:
                        throw PMKHTTPError.badStatusCode(code, Data(), http)
                    }
                }

                NSKeyedArchiver.archiveRootObject(response, toFile: self.cachedResponesURLForUser(user).path)

                let image = loadImageAtFileURL(self.imageURLForUser(user))
                completionBlock(true, image, nil)
            }.catch { error in
                completionBlock(true, loadImageAtFileURL(self.imageURLForUser(user)), error)
        }
    }
    
    func emptyCache() {
        do {
            try FileManager.default.removeItem(at: cacheFolder)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // nop
        } catch {
            Log.e("could not delete avatar cache at \(cacheFolder): \(error)")
        }
    }
    
    // MARK: Private
    
    private func imageURLForUser(_ user: User) -> URL {
        return cacheFolder
            .appendingPathComponent(user.userID, isDirectory: false)
            .appendingPathExtension("image")
    }
    
    private func cachedResponesURLForUser(_ user: User) -> URL {
        return cacheFolder
            .appendingPathComponent(user.userID, isDirectory: false)
            .appendingPathExtension("cachedresponse")
    }
}

private func defaultCacheFolder() -> URL {
    let caches = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return caches.appendingPathComponent("Avatars", isDirectory: true)
}

private func loadImageAtFileURL(_ url: URL) -> Any? {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let type = CGImageSourceGetType(source)
        else { return nil }
    
    if UTTypeConformsTo(type, kUTTypeGIF) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return FLAnimatedImage(animatedGIFData: data)
    }
    else {
        return UIImage(contentsOfFile: url.path)
    }
}
