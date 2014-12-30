//  DraftStore.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Saves drafts to and loads drafts from disk.
final class DraftStore {
    private let rootDirectory: NSURL
    
    /// rootDirectory should be a folder that can be deleted without consequence (e.g. "Application Support/Drafts"). It need not exist when the initializer is called.
    init(rootDirectory: NSURL) {
        self.rootDirectory = rootDirectory
    }
    
    /// Convenient singleton that saves drafts in the Application Support directory.
    class func sharedStore() -> DraftStore {
        struct Singleton {
            static var defaultDirectory: NSURL {
                return NSFileManager.defaultManager().applicationSupportDirectory.URLByAppendingPathComponent("Drafts", isDirectory: true)
            }
            
            static let instance = DraftStore(rootDirectory: defaultDirectory)
        }
        
        return Singleton.instance
    }
    
    /// Returns nil if no draft exists at the given path.
    func loadDraft(path: String) -> AnyObject? {
        let URL = URLForDraftAtPath(path)
        return NSKeyedUnarchiver.unarchiveObjectWithFile(URL.path!)
    }
    
    func saveDraft(draft: StorableDraft) {
        let URL = URLForDraftAtPath(draft.storePath)
        let enclosingDirectory = URL.URLByDeletingLastPathComponent!
        var error: NSError?
        if !NSFileManager.defaultManager().createDirectoryAtURL(enclosingDirectory, withIntermediateDirectories: true, attributes: nil, error: &error) {
            fatalError("could not create draft folder at \(enclosingDirectory): \(error!)")
        }
        
        NSKeyedArchiver.archiveRootObject(draft, toFile: URL.path!)
    }
    
    func deleteDraft(draft: StorableDraft) {
        let URL = URLForDraftAtPath(draft.storePath)
        let enclosingDirectory = URL.URLByDeletingLastPathComponent!
        var error: NSError?
        if !NSFileManager.defaultManager().removeItemAtURL(enclosingDirectory, error: &error) {
            if error!.domain == NSCocoaErrorDomain && error!.code == NSFileNoSuchFileError {
                return
            }
            
            fatalError("could not delete draft at \(enclosingDirectory): \(error!)")
        }
    }
    
    private func URLForDraftAtPath(path: String) -> NSURL {
        return NSURL(string: path, relativeToURL: rootDirectory)!.URLByAppendingPathComponent("Draft.dat")
    }
    
    /// Deletes all drafts in the draft store's rootDirectory.
    func deleteAllDrafts() {
        var error: NSError?
        if !NSFileManager.defaultManager().removeItemAtURL(rootDirectory, error: &error) {
            if error!.domain == NSCocoaErrorDomain && error!.code == NSFileNoSuchFileError {
                return
            }
            
            fatalError("could not delete all drafts at \(rootDirectory): \(error!)")
        }
    }
}

/// Something a DraftStore can deal with.
@objc protocol StorableDraft: NSCoding {
    /// A file system-safe path that uniquely describes this draft. For example, a draft reply to a particular thread might return "/reply/3510131". The path can be used later to retrieve the saved draft.
    var storePath: String { get }
}
