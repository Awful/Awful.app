// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation

internal struct TemporaryFolder {
    let url: URL
}

/// Creates a randomly-named folder in a temporary directory.
internal final class MakeTemporaryFolder: AsynchronousOperation<TemporaryFolder> {
    override func execute() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        log(.debug, "creating temporary folder at \(url)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

        log(.debug, "did create temporary folder at \(url)")
        finish(.success(TemporaryFolder(url: url)))
    }
}

/// Attempts to delete a temporary folder, but doesn't throw an error on failure (presumably the operating system will clean up after us).
internal final class DeleteTemporaryFolder: AsynchronousOperation<Void> {
    override func execute() throws {
        do {
            let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
            let url = tempFolder.url

            log(.debug, "deleting temporary folder at \(url)")
            try FileManager.default.removeItem(at: url)

            log(.debug, "did delete temporary folder at \(url)")
            finish(.success(()))
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            finish(.success(()))
        } catch {
            log(.info, "failed to delete temporary folder: \(error)")
            finish(.failure(error))
        }
    }
}
