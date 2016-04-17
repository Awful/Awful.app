//  ThreadTagLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import UIKit

/// Loads thread tag images, both those shipped with the app and those updated at the GitHub repository.
final class ThreadTagLoader: NSObject {
    /**
        Loads and caches a thread tag image using the convenient singleton.
     
        Failed requests (i.e. when nil is returned) may trigger a check for new thread tags. Observe newThreadTagsAvailableNotification to learn of newly-downloaded tag images.
     */
    class func imageNamed(imageName: String) -> UIImage? {
        return sharedLoader.imageNamed(imageName)
    }
    
    /// A generic image representing a thread.
    static var emptyThreadTagImage: UIImage {
        return UIImage(named: emptyThreadTagImageName)!
    }
    
    /// A generic image representing a private message.
    static var emptyPrivateMessageImage: UIImage {
        return UIImage(named: emptyPrivateMessageImageName)!
    }
    
    /// A placeholder image representing "no selection".
    static var unsetThreadTagImage: UIImage {
        return UIImage(named: unsetThreadTagImageName)!
    }
    
    /// A placeholder image representing "no filter".
    static var noFilterTagImage: UIImage {
        return UIImage(named: noFilterImageName)!
    }
    
    /// Convenient singleton.
    static let sharedLoader: ThreadTagLoader = {
        guard let
            tagListURLString = NSBundle(forClass: ThreadTagLoader.self).infoDictionary?["AwfulNewThreadTagListURL"] as? String,
            tagListURL = NSURL(string: tagListURLString)
            else { fatalError("missing AwfulNewThreadTagListURL in Info.plist") }
        let caches = try! NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let cacheFolder = caches.URLByAppendingPathComponent("Thread Tags", isDirectory: true)
        return ThreadTagLoader(tagListURL: tagListURL, cacheFolder: cacheFolder)
    }()
    
    private let tagListURL: NSURL
    private let cacheFolder: NSURL
    private let session: AFHTTPSessionManager
    private var downloadingNewTags = false
    
    /**
        - parameter tagListURL: The location of a list of tags available for download.
        - parameter cacheFolder: Where to save updated thread tags.
     */
    init(tagListURL: NSURL, cacheFolder: NSURL) {
        self.tagListURL = tagListURL
        self.cacheFolder = cacheFolder
        guard let baseURL = tagListURL.URLByDeletingLastPathComponent else { fatalError("couldn't derive base URL from tag list URL") }
        session = AFHTTPSessionManager(baseURL: baseURL)
        super.init()
        
        let responseSerializer = AFHTTPResponseSerializer()
        responseSerializer.acceptableContentTypes = ["text/plain"]
        session.responseSerializer = responseSerializer
    }
    
    // MARK: - imageNamed
    
    /**
        Loads and caches a thread tag image using the convenient singleton.
     
        Failed requests (i.e. when nil is returned) may trigger a check for new thread tags. Observe newThreadTagsAvailableNotification to learn of newly-downloaded tag images.
     */
    func imageNamed(imageName: String) -> UIImage? {
        let extensionless = (imageName as NSString).stringByDeletingPathExtension
        guard let image = shippedImageNamed(extensionless) ?? cachedImageNamed(extensionless) else {
            updateIfNecessary()
            return nil
        }
        return image
    }
    
    private func shippedImageNamed(imageName: String) -> UIImage? {
        let pathInFolder = (resourceSubfolder as NSString).stringByAppendingPathComponent(imageName)
        guard let image = UIImage(named: pathInFolder) ?? UIImage(named: imageName) else { return nil }
        guard image.scale >= 2 else {
            guard let cgimage = image.CGImage else { fatalError("missing CGImage from shipped thread tag") }
            return UIImage(CGImage: cgimage, scale: 2, orientation: image.imageOrientation)
        }
        return image
    }
    
    private func cachedImageNamed(imageName: String) -> UIImage? {
        let URL = cacheFolder.URLByAppendingPathComponent(imageName, isDirectory: false).URLByAppendingPathExtension("png")
        guard let path = URL.path, image = UIImage(contentsOfFile: path) else { return nil }
        guard image.scale >= 2 else {
            guard let cgimage = image.CGImage else { fatalError("missing CGImage from cached thread tag") }
            return UIImage(CGImage: cgimage, scale: 2, orientation: image.imageOrientation)
        }
        return image
    }
    
    // MARK: - Downloading images
    
    /// Checks for new thread tags.
    func updateIfNecessary() {
        guard !downloadingNewTags else { return }
        if lastUpdate.timeIntervalSinceNow > -60 * 60 { return }
        
        downloadingNewTags = true
        
        session.GET("tags.txt", parameters: nil, success: { [weak self] (task, textData) in
            guard let
                data = textData as? NSData,
                tagsFile = String(data: data, encoding: NSUTF8StringEncoding)
                else {
                    print("thread tag list decoding failed")
                    self?.downloadingNewTags = false
                    return
            }
            self?.saveTagsFile(tagsFile)
            
            let lines = tagsFile.componentsSeparatedByString("\n")
            guard let relativePath = lines.first else {
                print("couldn't find relative path in thread tag list")
                self?.downloadingNewTags = false
                return
            }
            let threadTags = lines.dropFirst()
            self?.downloadNewThreadTags(threadTags, fromRelativePath: relativePath) {
                self?.downloadingNewTags = false
            }
            
            }, failure: { [weak self] (task, error) in
                print("\(#function) error downloading new thread tag list: \(error)")
                self?.downloadingNewTags = false
        })
    }
    
    private var lastUpdate: NSDate {
        var modified: AnyObject?
        do {
            try cachedTagsFileURL.getResourceValue(&modified, forKey: NSURLAttributeModificationDateKey)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            // nop
        } catch {
            print("\(#function) error checking modification date of cached thread tags list: \(error)")
        }
        return modified as? NSDate ?? NSDate.distantPast()
    }
    
    private func saveTagsFile(tagsFile: String) {
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(cacheFolder, withIntermediateDirectories: true, attributes: nil)
            
            try tagsFile.writeToURL(cachedTagsFileURL, atomically: false, encoding: NSUTF8StringEncoding)
        } catch {
            print("\(#function) error: \(error)")
        }
    }
    
    private var cachedTagsFileURL: NSURL {
        return cacheFolder.URLByAppendingPathComponent("tags.txt", isDirectory: false)
    }
    
    private func downloadNewThreadTags<S: SequenceType where S.Generator.Element == String>(allThreadTags: S, fromRelativePath relativePath: String, completion: () -> Void) {
        var threadTags = Set(allThreadTags)
        threadTags.subtractInPlace(shippedThreadTagImageNames)
        threadTags.subtractInPlace(cachedThreadTagImageNames)
        
        let group = dispatch_group_create()
        
        for threadTagName in threadTags {
            dispatch_group_enter(group)
            
            guard let URL = NSURL(string: (relativePath as NSString).stringByAppendingPathComponent(threadTagName), relativeToURL: session.baseURL) else { continue }
            guard let request = try? session.requestSerializer.requestWithMethod("GET", URLString: URL.absoluteString, parameters: nil, error: ()) else { continue }
            session.downloadTaskWithRequest(request, progress: nil, destination: { (targetPath, response) -> NSURL in
                return self.cacheFolder.URLByAppendingPathComponent(threadTagName, isDirectory: false)
                
                }, completionHandler: { (response, filePath, error) in
                    defer { dispatch_group_leave(group) }
                    if let error = error {
                        print("\(#function) error download thread tag from \(URL): \(error)")
                        return
                    }
                    
                    let userInfo = [ThreadTagLoader.newImageNameKey: (threadTagName as NSString).stringByDeletingPathExtension]
                    NSNotificationCenter.defaultCenter().postNotificationName(ThreadTagLoader.newImageAvailableNotification, object: self, userInfo: userInfo)
            }).resume()
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue(), completion)
    }
    
    private var shippedThreadTagImageNames: [String] {
        let placeholderImageNames = [
            ThreadTagLoader.emptyThreadTagImageName,
            ThreadTagLoader.emptyPrivateMessageImageName,
            ThreadTagLoader.unsetThreadTagImageName,
            ThreadTagLoader.noFilterImageName]
        guard let shippedThreadTagFolder = NSBundle(forClass: ThreadTagLoader.self).resourceURL?.URLByAppendingPathComponent(resourceSubfolder, isDirectory: true) else { return placeholderImageNames }
        do {
            let URLs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(shippedThreadTagFolder, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles)
            return URLs.flatMap { $0.lastPathComponent } + placeholderImageNames
        } catch {
            print("\(#function) error listing shipped thread tags: \(error)")
            return placeholderImageNames
        }
    }
    
    private var cachedThreadTagImageNames: [String] {
        do {
            let URLs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(cacheFolder, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles)
            return URLs.flatMap { $0.lastPathComponent }
        } catch {
            print("\(#function) error listing cached thread tags: \(error)")
            return []
        }
    }
    
    // MARK: - Constants
    
    /// Posted when a thread tag image becomes newly available or updates. The notification's object is the AwfulThreadTagLoader that downloaded the image. The notification's userInfo contains a value for the newImageNameKey.
    static let newImageAvailableNotification = "com.awfulapp.Awful.ThreadTagLoaderNewImageAvailable"
    
    /// Value is a String suitable for AwfulThreadTagLoader.threadTagNamed(_:).
    static let newImageNameKey = "AwfulThreadTagLoaderNewImageName"
    
    // Names of placeholder images. Each of these has a convenience method on the ThreadTagLoader class.
    static let emptyThreadTagImageName = "empty-thread-tag"
    static let emptyPrivateMessageImageName = "empty-pm-tag"
    static let unsetThreadTagImageName = "unset-tag"
    static let noFilterImageName = "no-filter-icon"
}

private let resourceSubfolder = "Thread Tags"
