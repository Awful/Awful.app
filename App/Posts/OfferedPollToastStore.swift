//  OfferedPollToastStore.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "OfferedPollToastStore")

/// Remembers which threads have already had the "This thread has a poll" toast offered, so it's
/// shown the first time a thread is opened and never again.
///
/// One empty marker file per thread under Application Support, in the manner of `DraftStore`: a
/// lookup is a single file-exists check, and no list of IDs ever has to be loaded or rewritten,
/// however many threads pile up over the years. Nothing here is precious — losing the markers just
/// means a thread gets its toast again — so failures are logged rather than fatal.
final class OfferedPollToastStore {
    private let rootDirectory: URL

    /// `rootDirectory` should be a folder that can be deleted without consequence. It need not exist yet.
    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    static let shared: OfferedPollToastStore = {
        let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return OfferedPollToastStore(rootDirectory: appSupport.appendingPathComponent("OfferedPollToasts", isDirectory: true))
    }()

    func hasOffered(threadID: String) -> Bool {
        FileManager.default.fileExists(atPath: markerURL(threadID: threadID).path)
    }

    func markOffered(threadID: String) {
        let url = markerURL(threadID: threadID)
        do {
            try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try Data().write(to: url)
        } catch {
            logger.error("could not record the poll toast for thread \(threadID): \(error)")
        }
    }

    /// Forgets every thread, so each gets its toast again. Part of Settings → Empty Cache.
    func removeAll() {
        do {
            try FileManager.default.removeItem(at: rootDirectory)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
            // Nothing recorded yet.
        } catch {
            logger.error("could not remove the recorded poll toasts at \(self.rootDirectory.path): \(error)")
        }
    }

    /// Thread IDs are numeric strings, so they're safe to use as file names as they are.
    private func markerURL(threadID: String) -> URL {
        rootDirectory.appendingPathComponent(threadID, isDirectory: false)
    }
}
