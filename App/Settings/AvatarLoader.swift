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
    
    private let cacheFolder: NSURL
    private let sessionManager = AFURLSessionManager()
    
    init(cacheFolder: NSURL) {
        self.cacheFolder = cacheFolder
    }
    
    /// - returns: Either a UIImage or FLAnimatedImage if a cached avatar exists, otherwise nil.
    func cachedAvatarImageForUser(user: User) -> AnyObject? {
        let URL = imageURLForUser(user)
        return loadImageAtFileURL(URL)
    }
    
    /// - parameter completionBlock: A block that takes: `modified` which is `true` iff the image changed; `image`, either an FLAnimatedImage or a UIImage or nil; `error`, an NSError if an error occurred.
    func fetchAvatarImageForUser(user: User, completionBlock: (modified: Bool, image: AnyObject?, error: NSError?) -> Void) {
        guard let
            avatarURL = user.avatarURL,
            path = avatarURL.path where !path.isEmpty
            else { return completionBlock(modified: true, image: nil, error: nil) }
        let request = NSMutableURLRequest(URL: avatarURL)
        
        if let
            path = cachedResopnesURLForUser(user).path,
            oldResponse = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? NSHTTPURLResponse
            where oldResponse.URL == avatarURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }
        
        sessionManager.downloadTaskWithRequest(request, progress: nil, destination: { (targetPath, URLResponse) -> NSURL! in
            guard let
                response = URLResponse as? NSHTTPURLResponse
                where response.statusCode >= 200 && response.statusCode < 300
                else { return nil }
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(self.cacheFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("\(#function) error creating avatar cache folder \(self.cacheFolder): \(error)")
                return nil
            }
            
            let destinationURL = self.imageURLForUser(user)
            do {
                try NSFileManager.defaultManager().removeItemAtURL(destinationURL)
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // ok
            } catch let error as NSError {
                print("\(#function) error saving avatar to \(destinationURL): \(error)")
                // let's try downloading anyway
            }
            return destinationURL
            
            }, completionHandler: { (response, filePath, error) in
                if let
                    response = response,
                    path = self.cachedResopnesURLForUser(user).path
                {
                    NSKeyedArchiver.archiveRootObject(response, toFile: path)
                }
                
                if let
                    error = error,
                    response = error.userInfo[AFNetworkingOperationFailingURLResponseErrorKey] as? NSHTTPURLResponse
                    where response.statusCode == 304
                {
                    return completionBlock(modified: false, image: nil, error: nil)
                }
                
                let image = loadImageAtFileURL(self.imageURLForUser(user))
                completionBlock(modified: true, image: image, error: error)
        }).resume()
    }
    
    func emptyCache() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(cacheFolder)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            // nop
        } catch let error as NSError {
            print("\(#function) error deleting avatar cache at \(cacheFolder): \(error)")
        }
    }
    
    // MARK: Private
    
    private func imageURLForUser(user: User) -> NSURL {
        return cacheFolder
            .URLByAppendingPathComponent(user.userID)
            .URLByAppendingPathExtension("image")
    }
    
    private func cachedResopnesURLForUser(user: User) -> NSURL {
        return cacheFolder
            .URLByAppendingPathComponent(user.userID)
            .URLByAppendingPathExtension("cachedresponse")
    }
}

private func defaultCacheFolder() -> NSURL {
    let caches = try! NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
    return caches.URLByAppendingPathComponent("Avatars", isDirectory: true)
}

private func loadImageAtFileURL(URL: NSURL) -> AnyObject? {
    guard let
        source = CGImageSourceCreateWithURL(URL, nil),
        type = CGImageSourceGetType(source)
        else { return nil }
    if UTTypeConformsTo(type, kUTTypeGIF) {
        guard let data = NSData(contentsOfURL: URL) else { return nil }
        return FLAnimatedImage(animatedGIFData: data)
    } else {
        guard let path = URL.path else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
