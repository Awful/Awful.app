// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation
import ImageIO

#if canImport(CoreServices)
    import CoreServices
#else
    import MobileCoreServices
#endif

internal struct FormDataFile {
    let boundary: String
    let url: URL
}

internal enum WriteError: CustomNSError {
    case failedWritingData(underlyingError: Error)

    var errorUserInfo: [String: Any] {
        switch self {
        case .failedWritingData(underlyingError: let underlyingError):
            return [
                NSLocalizedDescriptionKey: "Upload request",
                NSLocalizedFailureReasonErrorKey: "Could not write request data",
                NSUnderlyingErrorKey: underlyingError]
        }
    }
}

internal final class WriteMultipartFormData: AsynchronousOperation<FormDataFile> {
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageFile = try firstDependencyValue(ofType: ImageFile.self)

        let uti = CGImageSourceCreateWithURL(imageFile.url as CFURL, nil)
            .flatMap { CGImageSourceGetType($0) }
        let mimeType = uti
            .flatMap { UTTypeCopyPreferredTagWithClass($0, kUTTagClassMIMEType)?.takeRetainedValue() as String? }
            ?? "application/octet-stream"

        let requestBodyURL = tempFolder.url
            .appendingPathComponent("request", isDirectory: false)
            .appendingPathExtension("dat")

        let boundary = makeBoundary()
        
        let pieces: [DataPiece] = [
            .inMemory({ makeTopData(boundary: boundary, mimeType: mimeType) }),
            .fromFile(imageFile.url),
            .inMemory({ makeBottomData(boundary: boundary) })]
        
        writeConcatenatedPieces(pieces, to: requestBodyURL, completion: { error in
            if let error = error {
                self.finish(.failure(WriteError.failedWritingData(underlyingError: error)))
            } else {
                self.finish(.success(FormDataFile(boundary: boundary, url: requestBodyURL)))
            }
        })
    }
}

private func makeBoundary() -> String {
    let randos = (0..<16).compactMap { _ in return boundaryDigits.randomElement() }
    return String(randos)
}

private let boundaryDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

private func makeTopData(boundary: String, mimeType: String) -> DispatchData {
    let top = [
        "--\(boundary)",
        "Content-Disposition: form-data; name=\"image\"; filename=\"image\"",
        "Content-Type: \(mimeType)",
        "\r\n",
        ]
        .joined(separator: "\r\n")
        .data(using: .utf8)!
    return top.withUnsafeBytes { DispatchData(bytes: $0) }
}

private func makeBottomData(boundary: String) -> DispatchData {
    let end = "\r\n--\(boundary)--".data(using: .utf8)!
    return end.withUnsafeBytes { DispatchData(bytes: $0) }
}

/// - Seealso: `writeConcatenatedPieces(_:to:completion:)`
private enum DataPiece {
    case fromFile(URL)
    case inMemory(() -> DispatchData)
}

/**
 Efficiently concatenates data from multiple sources (files and/or memory) into one destination file.
 
 Specifically, this function stays efficient by:
 
 - Loading file pieces in chunks to keep memory use constant and low.
 - Requesting in-memory pieces on-demand.
 
 - Parameter completion: A closure that is called from an arbitrary queue. It is passed `nil` on success, or an instance of `WriteConcatenatedPiecesError` on failure.
 */
private func writeConcatenatedPieces(_ pieces: [DataPiece], to destination: URL, completion: @escaping (Error?) -> Void) {
    precondition(destination.isFileURL, "can only write to file URLs")
    
    /* This function is difficult to read because of all the callbacks. Here's the general approach:
     
     1. Open a DispatchIO channel for the destination file.
     2. Write each piece to that channel in turn.
         - If there is an error during this step, either writing to the channel or reading from a file piece, then `completion` is called immediately.
     3. When all pieces are written, close the channel.
     4. When the channel closes successfully, call `completion`.
     */
    
    let queue = DispatchQueue(label: "Write concatenated data pieces")
    
    // We only want to call the completion handler once, so let's wrap it in an Optional and clear it when we call it. We only call it from the queue created above, so I'm not worried about synchronization here.
    var completionCalledOnce = Optional.some(completion)
    let completion: (Error?) -> Void = {
        completionCalledOnce?($0)
        completionCalledOnce = nil
    }
    
    let output = DispatchIO(
        __type: DispatchIO.StreamType.stream.rawValue,
        path: destination.path,
        oflag: O_CREAT | O_WRONLY,
        mode: S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH,
        queue: queue,
        handler: { error in
            if error == 0 {
                completion(nil)
            } else {
                completion(WriteConcatenatedPiecesError.failedWritingToDestination)
            }
    })
    
    var pieceIterator = pieces.enumerated().makeIterator()
    
    func writeNextPiece() {
        switch pieceIterator.next() {
        case let (i, .fromFile(source))?:
            let input = DispatchIO(
                __type: DispatchIO.StreamType.stream.rawValue,
                path: source.path,
                oflag: O_RDONLY,
                mode: 0,
                queue: queue,
                handler: { error in
                    if error == 0 {
                        queue.async { writeNextPiece() }
                    } else {
                        output.close(flags: .stop)
                        completion(WriteConcatenatedPiecesError.failedWritingPiece(index: i, dispatchErrorCode: error))
                    }
            })
            
            // This `Int` initializer seems to be the only way to pass `SIZE_MAX` in to this method, which is how you tell DispatchIO you want to read the entire file. It works fine, but it looks weird.
            input.read(offset: 0, length: Int(bitPattern: SIZE_MAX), queue: queue, ioHandler: { readDone, readData, readError in
                if readDone {
                    if readError == 0 {
                        input.close()
                        return
                    } else {
                        output.close(flags: .stop)
                        return completion(WriteConcatenatedPiecesError.failedReadingPiece(index: i, dispatchErrorCode: readError))
                    }
                }
                
                if let data = readData {
                    output.write(offset: 0, data: data, queue: queue, ioHandler: { writeDone, writeData, writeError in
                        if writeError != 0 {
                            input.close(flags: .stop)
                            output.close(flags: .stop)
                            completion(WriteConcatenatedPiecesError.failedWritingPiece(index: i, dispatchErrorCode: writeError))
                        }
                    })
                }
            })
            
        case let (i, .inMemory(data))?:
            output.write(offset: 0, data: data(), queue: queue) { done, data, error in
                guard done else {
                    // Just a progress report.
                    return
                }
                
                if error == 0 {
                    writeNextPiece()
                } else {
                    output.close(flags: .stop)
                    completion(WriteConcatenatedPiecesError.failedWritingPiece(index: i, dispatchErrorCode: error))
                }
            }
            
        case nil:
            output.close()
        }
    }
    
    queue.async { writeNextPiece() }
}

internal enum WriteConcatenatedPiecesError: Error {
    case failedReadingPiece(index: Int, dispatchErrorCode: Int32)
    case failedWritingToDestination
    case failedWritingPiece(index: Int, dispatchErrorCode: Int32)
}
