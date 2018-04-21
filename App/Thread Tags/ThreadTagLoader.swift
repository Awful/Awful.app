//  ThreadTagLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import PromiseKit
import UIKit

private let Log = Logger.get()

/// Loads thread tag images, both those shipped with the app and those updated at the GitHub repository.
final class ThreadTagLoader {
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
    static func unsetThreadTagImage(for forum: Forum? = nil) -> UIImage {
        let theme:  Theme
        if let forum = forum {
            theme = Theme.currentThemeForForum(forum: forum)
        } else {
            theme = Theme.currentTheme
        }
        return ImageTinting.tintImage(UIImage(named: unsetThreadTagImageName)!, as: theme["listTextColor"]!)!
        //return UIImage(named: unsetThreadTagImageName)!
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
    
    private let cacheFolder: URL
    private let objectionableImageNames: Set<String>
    private let session = URLSession(configuration: .ephemeral)
    private let tagListURL: URL
    private var downloadingNewTags = false
    
    /**
        - parameter tagListURL: The location of a list of tags available for download.
        - parameter cacheFolder: Where to save updated thread tags.
     */
    init(tagListURL: URL, cacheFolder: URL, objectionableImageNames: [String]) {
        self.tagListURL = tagListURL
        self.cacheFolder = cacheFolder
        self.objectionableImageNames = Set(objectionableImageNames)
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
    
    private func shippedImageNamed(_ imageName: String) -> UIImage? {
        let pathInFolder = (resourceSubfolder as NSString).appendingPathComponent(imageName)
        guard let image = UIImage(named: pathInFolder) ?? UIImage(named: imageName) else { return nil }
        guard image.scale >= 2 else {
            guard let cgimage = image.cgImage else { fatalError("missing CGImage from shipped thread tag") }
            return UIImage(cgImage: cgimage, scale: 2, orientation: image.imageOrientation)
        }
        return image
    }
    
    private func cachedImageNamed(_ imageName: String) -> UIImage? {
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
        if lastUpdate.timeIntervalSinceNow > -60 * 60 {
            return Log.d("not yet time to check for new thread tags")
        }

        Log.d("checking for new thread tags")
        downloadingNewTags = true

        session.dataTask(.promise, with: tagListURL)
            .validate()
            .done { data, response in
                guard let tagsFile = String(data: data, encoding: .utf8) else {
                    Log.e("thread tag list decoding failed")
                    self.downloadingNewTags = false
                    return
                }
                self.saveTagsFile(tagsFile)

                let lines = tagsFile.components(separatedBy: "\n")
                guard let relativePath = lines.first else {
                    Log.e("couldn't find relative path in thread tag list")
                    self.downloadingNewTags = false
                    return
                }
                let threadTags = lines.dropFirst()
                self.downloadNewThreadTags(threadTags, fromRelativePath: relativePath) {
                    Log.d("done downloading new thread tags")
                    self.downloadingNewTags = false
                }
            }.catch { error in
                Log.e("could not download new thread tag list: \(error)")
                self.downloadingNewTags = false
        }
    }
    
    private var lastUpdate: Date {
        var modified: AnyObject?
        do {
            try (cachedTagsFileURL as NSURL).getResourceValue(&modified, forKey: .attributeModificationDateKey)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // nop
        } catch {
            Log.e("could not check modification date of cached thread tags list: \(error)")
        }
        return modified as? Date ?? .distantPast
    }
    
    private func saveTagsFile(_ tagsFile: String) {
        do {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
            
            try tagsFile.write(to: cachedTagsFileURL, atomically: false, encoding: String.Encoding.utf8)
        } catch {
            Log.e("could not save tags file: \(error)")
        }
    }
    
    private var cachedTagsFileURL: URL {
        return cacheFolder.appendingPathComponent("tags.txt", isDirectory: false)
    }
    
    private func downloadNewThreadTags<S: Sequence>(_ allThreadTags: S, fromRelativePath relativePath: String, completion: @escaping () -> Void) where S.Iterator.Element == String {
        var threadTags = Set(allThreadTags)
        threadTags.subtract(Set(shippedThreadTagImageNames))
        threadTags.subtract(Set(cachedThreadTagImageNames))

        Log.d("downloading \(threadTags.count) new thread tag\(threadTags.count == 1 ? "" : "s")")
        
        let group = DispatchGroup()
        
        for threadTagName in threadTags {
            group.enter()

            let baseURL = tagListURL.deletingLastPathComponent()
            guard
                let url = URL(string: (relativePath as NSString).appendingPathComponent(threadTagName), relativeTo: baseURL)
                else { continue }

            session.downloadTask(.promise, with: url, to: cacheFolder.appendingPathComponent(threadTagName, isDirectory: false), replacingIfNecessary: true)
                .done { saveLocation, response in
                    let userInfo = [ThreadTagLoader.NewImageAvailableNotification.newImageNameKey: (threadTagName as NSString).deletingPathExtension]
                    NotificationCenter.default.post(name: ThreadTagLoader.NewImageAvailableNotification.name, object: self, userInfo: userInfo)
                }.catch { error in
                    Log.e("could not download thread tag from \(url): \(error)")
                }
                .finally {
                    group.leave()
            }
        }
        
        group.notify(queue: .main, execute: completion)
    }
    
    private var shippedThreadTagImageNames: [String] {
        let placeholderImageNames = [
            ThreadTagLoader.emptyThreadTagImageName,
            ThreadTagLoader.emptyPrivateMessageImageName,
            ThreadTagLoader.unsetThreadTagImageName,
            ThreadTagLoader.noFilterImageName]
        guard let shippedThreadTagFolder = Bundle(for: ThreadTagLoader.self).resourceURL?.appendingPathComponent(resourceSubfolder, isDirectory: true) else { return placeholderImageNames }
        do {
            let URLs = try FileManager.default.contentsOfDirectory(at: shippedThreadTagFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return URLs.compactMap { $0.lastPathComponent } + placeholderImageNames
        } catch {
            Log.e("could not list shipped thread tags: \(error)")
            return placeholderImageNames
        }
    }
    
    private var cachedThreadTagImageNames: [String] {
        do {
            let URLs = try FileManager.default.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return URLs.compactMap { $0.lastPathComponent }
        } catch {
            Log.e("could not list cached thread tags: \(error)")
            return []
        }
    }
    
    // MARK: - Constants

    /// Posted when a thread tag image becomes newly available or updates. The notification's object is the AwfulThreadTagLoader that downloaded the image. The notification's userInfo contains a value for the newImageNameKey.
    struct NewImageAvailableNotification {
        static let name = Notification.Name(rawValue: "com.awfulapp.Awful.ThreadTagLoaderNewImageAvailable")
        static let newImageNameKey = "AwfulThreadTagLoaderNewImageName"

        /// A string suitable for `ThreadTagLoader.threadTagNamed(_:)`.
        let newImageName: String

        init(_ notification: Notification) {
            guard notification.name == NewImageAvailableNotification.name else {
                fatalError("wrong notification")
            }

            newImageName = notification.userInfo![NewImageAvailableNotification.newImageNameKey] as! String
        }
    }
    
    // Names of placeholder images. Each of these has a convenience method on the ThreadTagLoader class.
    static let emptyThreadTagImageName = "empty-thread-tag"
    static let emptyPrivateMessageImageName = "empty-pm-tag"
    static let unsetThreadTagImageName = "unset-tag"
    static let noFilterImageName = "no-filter-icon"
}

private let resourceSubfolder = "Thread Tags"
