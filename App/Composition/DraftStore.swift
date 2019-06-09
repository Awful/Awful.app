//  DraftStore.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Saves drafts to and loads drafts from disk.
final class DraftStore {
    fileprivate let rootDirectory: URL
    
    /// rootDirectory should be a folder that can be deleted without consequence (e.g. "Application Support/Drafts"). It need not exist when the initializer is called.
    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }
    
    /// Convenient singleton that saves drafts in the Application Support directory.
    class func sharedStore() -> DraftStore {
        struct Singleton {
            static var defaultDirectory: URL {
                let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                return appSupport.appendingPathComponent("Drafts", isDirectory: true)
            }
            
            static let instance = DraftStore(rootDirectory: defaultDirectory)
        }
        
        return Singleton.instance
    }
    
    /// Returns nil if no draft exists at the given path.
    func loadDraft(_ path: String) -> AnyObject? {
        let URL = URLForDraftAtPath(path)
        return NSKeyedUnarchiver.unarchiveObject(withFile: URL.path) as AnyObject?
    }
    
    func saveDraft(_ draft: StorableDraft) {
        let URL = URLForDraftAtPath(draft.storePath)
        let enclosingDirectory = URL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: enclosingDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            fatalError("could not create draft folder at \(enclosingDirectory): \(error)")
        }
        
        NSKeyedArchiver.archiveRootObject(draft, toFile: URL.path)
    }
    
    func deleteDraft(_ draft: StorableDraft) {
        let URL = URLForDraftAtPath(draft.storePath)
        let enclosingDirectory = URL.deletingLastPathComponent()
        do {
            try FileManager.default.removeItem(at: enclosingDirectory)
        }
        catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                return
            }
            
            fatalError("could not delete draft at \(enclosingDirectory): \(error)")
        }
    }
    
    fileprivate func URLForDraftAtPath(_ path: String) -> URL {
        return URL(string: path, relativeTo: rootDirectory)!.appendingPathComponent("Draft.dat")
    }
    
    /// Deletes all drafts in the draft store's rootDirectory.
    func deleteAllDrafts() {
        do {
            try FileManager.default.removeItem(at: rootDirectory)
        }
        catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                return
            }
            
            fatalError("could not delete all drafts at \(rootDirectory): \(error)")
        }
    }
}

/// Something a DraftStore can deal with.
@objc protocol StorableDraft: NSCoding {
    /// A file system-safe path that uniquely describes this draft. For example, a draft reply to a particular thread might return "/reply/3510131". The path can be used later to retrieve the saved draft.
    var storePath: String { get }
}
