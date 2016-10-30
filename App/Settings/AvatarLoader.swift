//  AvatarLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import AwfulCore
import FLAnimatedImage
import ImageIO
import UIKit

/// Fetches and caches avatar images.
final class AvatarLoader: NSObject {
    static let sharedLoader = AvatarLoader(cacheFolder: defaultCacheFolder())
    
    fileprivate let cacheFolder: URL
    fileprivate let sessionManager = AFURLSessionManager()
    
    init(cacheFolder: URL) {
        self.cacheFolder = cacheFolder
    }
    
    /// - returns: Either a UIImage or FLAnimatedImage if a cached avatar exists, otherwise nil.
    func cachedAvatarImageForUser(_ user: User) -> AnyObject? {
        let URL = imageURLForUser(user)
        return loadImageAtFileURL(URL)
    }
    
    /// - parameter completionBlock: A block that takes: `modified` which is `true` iff the image changed; `image`, either an FLAnimatedImage or a UIImage or nil; `error`, an NSError if an error occurred.
    func fetchAvatarImageForUser(_ user: User, completionBlock: @escaping (_ modified: Bool, _ image: AnyObject?, _ error: NSError?) -> Void) {
        guard let avatarURL = user.avatarURL, !avatarURL.path.isEmpty else {
            return completionBlock(true, nil, nil)
        }
        let request = NSMutableURLRequest(url: avatarURL as URL)
        
        if let oldResponse = NSKeyedUnarchiver.unarchiveObject(withFile: cachedResponesURLForUser(user).path) as? HTTPURLResponse,
            oldResponse.url == avatarURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }
        
        sessionManager.downloadTask(with: request as URLRequest!, progress: nil, destination: { (targetPath, URLResponse) -> URL? in
            guard let
                response = URLResponse as? HTTPURLResponse
                , response.statusCode >= 200 && response.statusCode < 300
                else { return nil }
            
            do {
                try FileManager.default.createDirectory(at: self.cacheFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("\(#function) error creating avatar cache folder \(self.cacheFolder): \(error)")
                return nil
            }
            
            let destinationURL = self.imageURLForUser(user)
            do {
                try FileManager.default.removeItem(at: destinationURL)
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // ok
            } catch let error as NSError {
                print("\(#function) error saving avatar to \(destinationURL): \(error)")
                // let's try downloading anyway
            }
            return destinationURL
            
            }, completionHandler: { (response, filePath, error) in
                NSKeyedArchiver.archiveRootObject(response, toFile: self.cachedResponesURLForUser(user).path)
                
                if
                    let error = error,
                    let response = (error as NSError).userInfo[AFNetworkingOperationFailingURLResponseErrorKey] as? HTTPURLResponse,
                    response.statusCode == 304
                {
                    return completionBlock(false, nil, nil)
                }
                
                let image = loadImageAtFileURL(self.imageURLForUser(user))
                completionBlock(true, image, error as NSError?)
        }).resume()
    }
    
    func emptyCache() {
        do {
            try FileManager.default.removeItem(at: cacheFolder)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            // nop
        } catch let error as NSError {
            print("\(#function) error deleting avatar cache at \(cacheFolder): \(error)")
        }
    }
    
    // MARK: Private
    
    fileprivate func imageURLForUser(_ user: User) -> URL {
        return cacheFolder
            .appendingPathComponent(user.userID)
            .appendingPathExtension("image")
    }
    
    fileprivate func cachedResponesURLForUser(_ user: User) -> URL {
        return cacheFolder
            .appendingPathComponent(user.userID)
            .appendingPathExtension("cachedresponse")
    }
}

private func defaultCacheFolder() -> URL {
    let caches = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return caches.appendingPathComponent("Avatars", isDirectory: true)
}

private func loadImageAtFileURL(_ url: URL) -> AnyObject? {
    guard let
        source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let type = CGImageSourceGetType(source)
        else { return nil }
    if UTTypeConformsTo(type, kUTTypeGIF) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return FLAnimatedImage(animatedGIFData: data)
    } else {
        return UIImage(contentsOfFile: url.path)
    }
}
