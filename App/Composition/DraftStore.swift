//  DraftStore.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DraftStore")

/// Saves drafts to and loads drafts from disk.
final class DraftStore {
    fileprivate let rootDirectory: URL

    /// All file system work goes through here, in order, so a delete queued after a save wins and a
    /// load sees the most recent save.
    private let ioQueue = DispatchQueue(label: "com.awfulapp.Awful.DraftStore.io", qos: .utility)
    
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
        let url = URLForDraftAtPath(path)
        do {
            let data = try ioQueue.sync { try Data(contentsOf: url) }
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as AnyObject?
        } catch {
            logger.error("could not load draft at \(path): \(error)")
            return nil
        }
    }

    /**
     Archives `draft` on the calling thread and writes the archive to disk on a background queue.

     Archiving stays on the caller because drafts encode main-context managed objects. Pass
     `waitUntilFinished: true` when the file must exist on return (e.g. the sheet is being dismissed).
     */
    func saveDraft(_ draft: StorableDraft, waitUntilFinished: Bool = false) {
        let url = URLForDraftAtPath(draft.storePath)
        let enclosingDirectory = url.deletingLastPathComponent()

        #if DEBUG
        let archiveStart = CFAbsoluteTimeGetCurrent()
        #endif
        let data = try! NSKeyedArchiver.archivedData(withRootObject: draft, requiringSecureCoding: false)
        #if DEBUG
        let archiveMilliseconds = (CFAbsoluteTimeGetCurrent() - archiveStart) * 1000
        logger.debug("archived \(draft.storePath): \(data.count) bytes in \(archiveMilliseconds, format: .fixed(precision: 1)) ms")
        #endif

        let write = {
            do {
                try FileManager.default.createDirectory(at: enclosingDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                fatalError("could not create draft folder at \(enclosingDirectory): \(error)")
            }
            try! data.write(to: url, options: .atomic)
        }
        if waitUntilFinished {
            ioQueue.sync(execute: write)
        } else {
            ioQueue.async(execute: write)
        }
    }
    
    func deleteDraft(_ draft: StorableDraft) {
        let enclosingDirectory = URLForDraftAtPath(draft.storePath).deletingLastPathComponent()
        ioQueue.sync {
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
    }
    
    fileprivate func URLForDraftAtPath(_ path: String) -> URL {
        return URL(string: path, relativeTo: rootDirectory)!.appendingPathComponent("Draft.dat")
    }
    
    /// Deletes all drafts in the draft store's rootDirectory.
    func deleteAllDrafts() {
        ioQueue.sync {
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
}

/// Something a DraftStore can deal with.
@objc protocol StorableDraft: NSCoding {
    /// A file system-safe path that uniquely describes this draft. For example, a draft reply to a particular thread might return "/reply/3510131". The path can be used later to retrieve the saved draft.
    var storePath: String { get }
}
