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
    class func imageNamed(_ imageName: String) -> UIImage? {
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
        let bundle = Bundle(for: ThreadTagLoader.self)
        guard
            let tagListURLString = bundle.infoDictionary?["AwfulNewThreadTagListURL"] as? String,
            let tagListURL = URL(string: tagListURLString)
            else { fatalError("missing AwfulNewThreadTagListURL in Info.plist") }
        
        guard
            let objectionableURL = bundle.url(forResource: "PotentiallyObjectionableThreadTags", withExtension: "plist"),
            let objectionableImageNames = NSArray(contentsOf: objectionableURL) as? [String]
            else { fatalError("Missing PotentiallyObjectionableThreadTags.plist resource") }
        
        let caches = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheFolder = caches.appendingPathComponent("Thread Tags", isDirectory: true)
        
        return ThreadTagLoader(tagListURL: tagListURL, cacheFolder: cacheFolder, objectionableImageNames: objectionableImageNames)
    }()
    
    fileprivate let tagListURL: URL
    fileprivate let cacheFolder: URL
    fileprivate let session: AFHTTPSessionManager
    fileprivate var downloadingNewTags = false
    fileprivate let objectionableImageNames: Set<String>
    
    /**
        - parameter tagListURL: The location of a list of tags available for download.
        - parameter cacheFolder: Where to save updated thread tags.
     */
    init(tagListURL: URL, cacheFolder: URL, objectionableImageNames: [String]) {
        self.tagListURL = tagListURL
        self.cacheFolder = cacheFolder
        self.objectionableImageNames = Set(objectionableImageNames)
        let baseURL = tagListURL.deletingLastPathComponent()
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
    func imageNamed(_ imageName: String) -> UIImage? {
        let extensionless = (imageName as NSString).deletingPathExtension
        
        // App Review :(
        if objectionableImageNames.contains(extensionless) {
            return nil
        }
        
        guard let image = shippedImageNamed(extensionless) ?? cachedImageNamed(extensionless) else {
            updateIfNecessary()
            return nil
        }
        return image
    }
    
    fileprivate func shippedImageNamed(_ imageName: String) -> UIImage? {
        let pathInFolder = (resourceSubfolder as NSString).appendingPathComponent(imageName)
        guard let image = UIImage(named: pathInFolder) ?? UIImage(named: imageName) else { return nil }
        guard image.scale >= 2 else {
            guard let cgimage = image.cgImage else { fatalError("missing CGImage from shipped thread tag") }
            return UIImage(cgImage: cgimage, scale: 2, orientation: image.imageOrientation)
        }
        return image
    }
    
    fileprivate func cachedImageNamed(_ imageName: String) -> UIImage? {
        let url = cacheFolder.appendingPathComponent(imageName, isDirectory: false).appendingPathExtension("png")
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        guard image.scale >= 2 else {
            guard let cgimage = image.cgImage else { fatalError("missing CGImage from cached thread tag") }
            return UIImage(cgImage: cgimage, scale: 2, orientation: image.imageOrientation)
        }
        return image
    }
    
    // MARK: - Downloading images
    
    /// Checks for new thread tags.
    func updateIfNecessary() {
        guard !downloadingNewTags else { return }
        if lastUpdate.timeIntervalSinceNow > -60 * 60 { return }
        
        downloadingNewTags = true
        
        session.get("tags.txt", parameters: nil, success: { [weak self] (task, textData) in
            guard let
                data = textData as? Data,
                let tagsFile = String(data: data, encoding: String.Encoding.utf8)
                else {
                    print("thread tag list decoding failed")
                    self?.downloadingNewTags = false
                    return
            }
            self?.saveTagsFile(tagsFile)
            
            let lines = tagsFile.components(separatedBy: "\n")
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
    
    fileprivate var lastUpdate: Date {
        var modified: AnyObject?
        do {
            try (cachedTagsFileURL as NSURL).getResourceValue(&modified, forKey: URLResourceKey.attributeModificationDateKey)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            // nop
        } catch {
            print("\(#function) error checking modification date of cached thread tags list: \(error)")
        }
        return modified as? Date ?? Date.distantPast
    }
    
    fileprivate func saveTagsFile(_ tagsFile: String) {
        do {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
            
            try tagsFile.write(to: cachedTagsFileURL, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            print("\(#function) error: \(error)")
        }
    }
    
    fileprivate var cachedTagsFileURL: URL {
        return cacheFolder.appendingPathComponent("tags.txt", isDirectory: false)
    }
    
    fileprivate func downloadNewThreadTags<S: Sequence>(_ allThreadTags: S, fromRelativePath relativePath: String, completion: @escaping () -> Void) where S.Iterator.Element == String {
        var threadTags = Set(allThreadTags)
        threadTags.subtract(Set(shippedThreadTagImageNames))
        threadTags.subtract(Set(cachedThreadTagImageNames))
        
        let group = DispatchGroup()
        
        for threadTagName in threadTags {
            group.enter()
            
            guard let URL = NSURL(string: (relativePath as NSString).appendingPathComponent(threadTagName), relativeTo: session.baseURL) else { continue }
            let request = session.requestSerializer.request(withMethod: "GET", urlString: URL.absoluteString!, parameters: nil, error: nil)
            session.downloadTask(with: request as URLRequest, progress: nil, destination: { (targetPath, response) -> URL in
                return self.cacheFolder.appendingPathComponent(threadTagName, isDirectory: false)
                
                }, completionHandler: { (response, filePath, error) in
                    defer { group.leave() }
                    if let error = error {
                        print("\(#function) error download thread tag from \(URL): \(error)")
                        return
                    }
                    
                    let userInfo = [ThreadTagLoader.newImageNameKey: (threadTagName as NSString).deletingPathExtension]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: ThreadTagLoader.newImageAvailableNotification), object: self, userInfo: userInfo)
            }).resume()
        }
        
        group.notify(queue: .main, execute: completion)
    }
    
    fileprivate var shippedThreadTagImageNames: [String] {
        let placeholderImageNames = [
            ThreadTagLoader.emptyThreadTagImageName,
            ThreadTagLoader.emptyPrivateMessageImageName,
            ThreadTagLoader.unsetThreadTagImageName,
            ThreadTagLoader.noFilterImageName]
        guard let shippedThreadTagFolder = Bundle(for: ThreadTagLoader.self).resourceURL?.appendingPathComponent(resourceSubfolder, isDirectory: true) else { return placeholderImageNames }
        do {
            let URLs = try FileManager.default.contentsOfDirectory(at: shippedThreadTagFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return URLs.flatMap { $0.lastPathComponent } + placeholderImageNames
        } catch {
            print("\(#function) error listing shipped thread tags: \(error)")
            return placeholderImageNames
        }
    }
    
    fileprivate var cachedThreadTagImageNames: [String] {
        do {
            let URLs = try FileManager.default.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
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
