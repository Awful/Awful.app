// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/**
 An Imgur API client for anonymous image uploads.
 
 This client has a very narrow focus: efficiently and anonymously uploading images to Imgur. No other aspects of the Imgur API are available.
 
 Efficiency is meant in two ways: developer efficiency (that's you!) and efficient use of device resources (namely memory). It is not usually terribly difficult to take a `UIImage` you have in memory, obtain a PNG data representation, create a `multipart/form-data` request, and pass that along to a `URLSession`. Life gets annoying when you're writing that pipeline for the fifteenth time, or when you start crashing because you run out of memory trying to resize a gigantic source image by drawing it to a bitmap context. Sometimes you have a `UIImagePickerController` giving you an info dictionary and you just wanna turn that into an Imgur URL, and you don't want to think about it too hard.
 
 The Imgur API enforces various rate limits. As of this writing (2018-11-11), the documentation explains: "Each application can allow approximately 1,250 uploads per day or approximately 12,500 requests per day. If the daily limit is hit five times in a month, then the app will be blocked for the rest of the month." Furthermore, "We also limit each user (via their IP Address) for each application, this is to ensure that no single user is able to spam an application. This limit will simply stop the user from requesting more data for an hour."
 
 Each instance method calls its completion handler with, among other data, the most up-to-date rate limiting information. You might use this information to throttle your calls to the Imgur API or to present more detailed error information to your user.
 
 Since we're talking to the Imgur anonymous image upload API, we use an ephemeral `URLSession`.
 
 Finally, the Imgur API is free for non-commercial use only. "Your application is commercial if you're making any money with it (which includes in-app advertising), if you plan on making any money with it, or if it belongs to a commercial organization." Please see https://apidocs.imgur.com for more details; search for "Commercial Usage" on that page.
 */
public final class ImgurUploader {

    /**
     Create an Imgur anonymous image API client.
     
     - Parameter clientID: A client ID obtained by registering your application with Imgur.
     - Parameter userAgent: If you wish to customize the `User-Agent` header sent to Imgur, you can provide it here.
     
     All interaction with the Imgur API requires a client ID. You can obtain a new one:
     
     1. Sign up for an Imgur account at https://imgur.com/register
     2. Register an application at https://api.imgur.com/oauth2/addclient
     
     After registering an application, you can find the list of your registered client IDs by visiting https://imgur.com/account/settings/apps
     
     Certain API limits are attributed to your client ID and you're generally responsible for its use, so you should keep it somewhat secret (e.g. consider not checking it in to a public repository). Especially if you are paying for commercial usage.
     
     Remember that the Imgur API is free for non-commercial use only. "Your application is commercial if you're making any money with it (which includes in-app advertising), if you plan on making any money with it, or if it belongs to a commercial organization." See https://apidocs.imgur.com for more details (search for "Commercial Usage" on that page).
     */
    public init(clientID: String, userAgent: String = "") {
        queue = OperationQueue()
        queue.name = "com.nolanw.ImgurAnonymousAPI"

        urlSession = URLSession(configuration: {
            let config = URLSessionConfiguration.ephemeral
            var additionalHeaders = ["Authorization": "Client-ID \(clientID)"]
            if !userAgent.isEmpty {
                additionalHeaders["User-Agent"] = userAgent
            }
            config.httpAdditionalHeaders = additionalHeaders
            return config
        }())
    }

    /**
     All uploaders log messages by calling this closure. If you are interested in log messages, maybe during development and/or to pass them along to your existing logging framework, you can set your own closure here.
     
     - Warning: Any closure set here can and will be invoked on arbitrary dispatch queues!
     */
    public static var logger: ((_ level: LogLevel, _ message: () -> String) -> Void)?

    public enum LogLevel: Comparable {
        
        /// Messages not particularly interesting unless you suspect an `ImgurAnonymousAPI` instance is misbehaving.
        case debug
        
        /// Messages that are not worth `throw`ing about, but may nonetheless be interesting during normal operation.
        case info
        
        /// Messages that will result in a `throw`n error.
        case error

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            switch (lhs, rhs) {
            case (.debug, .info), (.debug, .error):
                return true
            case (.info, .error):
                return true
            case (.debug, _), (.info, _), (.error, _):
                return false
            }
        }
    }
    
    /// One of several possible error types that can be provided to a completion handler on failure.
    public enum Error: Swift.Error {
        
        /// The Imgur API did not like your client ID. Double-check your registered client IDs at https://imgur.com/account/settings/apps, or register a new one at https://api.imgur.com/oauth2/addclient
        case invalidClientID
        
        /// The provided `UIImagePickerController` info dictionary did not include any image that `ImgurUploader` understands how to upload.
        case noUploadableImageFromImagePicker
    }

    // MARK: - Implementation details
    
    private let queue: OperationQueue
    private let urlSession: URLSession

    // MARK: - Photos.framework support
    
    #if canImport(Photos)

    /**
     Anonymously uploads a Photos asset to Imgur, resizing the image as necessary to fit under the Imgur Upload API's maximum file size limit.
     
     Animated images are somewhat supported: they are uploaded as-is, and if their file size is too large, they are not resized.
     
     This upload uses Imgur API rate limit credits.
     
     - Parameter asset: A Photos asset with at least one photo representation.
     - Parameter completion: A closure to call when the upload completes. The closure is always called on the main queue.
     - Returns: A cancellable `Progress` instance.
     
     - Warning: Calling this method will show your user a photo library authorization alert (or crash if your app is missing an `Info.plist` value for the key `NSPhotoLibraryUsageDescription`).
     */
    @available(macOS 10.13, tvOS 10.0, *)
    @discardableResult
    public func upload(_ asset: PHAsset, completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {
        return upload(imageSaveOperation: SavePHAsset(asset), completion: completion)
    }
    
    #endif
    
    // MARK: - UIKit support
    
    #if canImport(UIKit)
    
    /**
     Anonymously uploads a `UIImage` to Imgur, resizing the image as necessary to fit under the Imgur Upload API's maximum file size limit.
     
     Only `UIImage`s backed by `CGImage` are supported. `CIImage`-backed images will fail immediately.
     
     Animated images are somewhat supported: they are saved as a GIF and uploaded as-is, and if their file size is too large, they are not resized. The underlying image framework, ImageIO, is not known for its particularly optimized GIF output.
     
     This upload uses Imgur API rate limit credits.
     
     - Parameter image: An image instance (animated or not).
     - Parameter completion: A closure to call when the upload completes. The closure is always called on the main queue.
     - Returns: A cancellable `Progress` instance.
     */
    @discardableResult
    public func upload(_ image: UIImage, completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {
        return upload(imageSaveOperation: SaveUIImage(image), completion: completion)
    }
    
    #endif
    
    #if canImport(UIKit) && !os(tvOS) && !os(watchOS)

    /**
     Anonymously uploads a user-chosen image to Imgur, resizing the image as necessary to fit under the Imgur Upload API's maximum file size limit.
     
     This is a helper method that conveniently calls one of the other overloads of `upload(_completion:)` that take a `PHAsset` or a `UIImage`.
     
     If the user has authorized photo library access, image data is obtained directly from the photo library. However, this method will never result in the user being asked to authorize photo library access (and it will not crash if your app's `Info.plist` has no value for `NSPhotoLibraryUsageDescription`). If photo library access has not been authorized, the `UIImage` instance is used instead.
     
     Animated images are somewhat supported: if photo library access has been granted, the image data is uploaded as-is. If an animated image's file size is too large, it are not resized and the upload fails. Note that `UIImagePickerController` does not seem to provide animated instances of `UIImage`, so if the user has not authorized photo library access then only the first frame of an animated image is uploaded. Also note that, as mentioned, this method will never result in the user being asked to authorize photo library access; if your user is likely to pick an animated image for upload, consider requesting photo library authorization beforehand.
     
     Note that as of iOS 11 (?) you can use a `UIImagePickerController`, and pass the resulting info dictionary to this method, without bothering with `NSPhotoLibraryUsageDescription` or photo library authorization.
     
     - Parameter info: An info dictionary as passed to `UIImagePickerControllerDelegate.imagePickerController(_:didFinishPickingMediaWithInfo:)`.
     - Parameter completion: A closure to call when the upload completes. The closure is always called on the main queue.
     - Returns: A cancellable `Progress` instance.
     */
    @discardableResult
    public func upload(_ info: [UIImagePickerController.InfoKey: Any], completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {

        var asset: PHAsset? {
            guard SavePHAsset.hasRequiredPhotoLibraryAuthorization else {
                log(.debug, "not using photo library to obtain image data as the user has not authorized photo library use")
                return nil
            }
            
            if #available(iOS 11.0, *), let asset = info[.phAsset] as? PHAsset {
                return asset
            } else if let assetURL = info[.referenceURL] as? URL {
                return PHAsset.fetchAssets(withALAssetURLs: [assetURL], options: nil).firstObject
            } else {
                return nil
            }
        }

        var image: UIImage? {
            return info[.editedImage] as? UIImage
                ?? info[.originalImage] as? UIImage
        }

        if let asset = asset {
            return upload(asset, completion: completion)
        } else if let image = image {
            return upload(image, completion: completion)
        } else {
            log(.error, "no uploadable images from image picker info: \(info)")
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1

            OperationQueue.main.addOperation {
                completion(.failure(ImgurUploader.Error.noUploadableImageFromImagePicker))
            }

            return progress
        }
    }
    
    #endif

    // MARK: - Generic uploading and support

    private func upload(imageSaveOperation: Operation, completion: @escaping (_ result: Result<UploadResponse>) -> Void) -> Progress {
        let tempFolder = MakeTemporaryFolder()

        imageSaveOperation.addDependency(tempFolder)

        let resize = ResizeImage(maximumFileSizeBytes: imgurFileSizeLimit)
        resize.addDependency(imageSaveOperation)
        resize.addDependency(tempFolder)

        let writeFormData = WriteMultipartFormData()
        writeFormData.addDependency(resize)
        writeFormData.addDependency(tempFolder)

        let upload = UploadImageAsFormData(urlSession: urlSession, request: {
            var request = URLRequest(url: URL(string: "https://api.imgur.com/3/image")!)
            request.httpMethod = "POST"
            return request
        }())
        upload.addDependency(writeFormData)

        let deleteTempFolder = DeleteTemporaryFolder()
        deleteTempFolder.addDependency(tempFolder)
        deleteTempFolder.addDependency(upload)

        let ops = [tempFolder, imageSaveOperation, resize, writeFormData, upload, deleteTempFolder]

        log(.debug, "starting upload of \(imageSaveOperation)")
        queue.addOperations(ops, waitUntilFinished: false)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling upload of \(imageSaveOperation)")
            for op in ops where !(op is DeleteTemporaryFolder) {
                op.cancel()
            }
        }

        let completionOp = BlockOperation {
            let result = upload.result!
            log(.debug, "finishing upload of \(imageSaveOperation) with \(result)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(ops.last!)
        OperationQueue.main.addOperation(completionOp)

        return progress
    }

    /// Communication with the Imgur API either succeeds or fails, but never both. Completion handlers are called with an instance of this typical `Result` type.
    public enum Result<T> {
        case success(T)
        case failure(Swift.Error)

        public var value: T? {
            switch self {
            case .success(let value):
                return value
            case .failure:
                return nil
            }
        }

        internal func unwrap() throws -> T {
            switch self {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }

    /**
     The parsed response from a successful upload to the Imgur anonymous image API.
     */
    public struct UploadResponse {
        
        /// The newly-uploaded image's ID, which forms part of many URLs relating to the image.
        public let id: String
        
        /// The URL pointing at the uploaded image, suitable for downloading or use e.g. in an `<img>` element.
        public let link: URL
        
        /// How many more uploads (`POST` requests) are allowed in the near future, or `nil` if that information is unavailable.
        public let postLimit: PostLimit?
        
        /// How many more API calls are allowed in the near future, or `nil` if that information is unavailable.
        public let rateLimit: RateLimit? // optional for same reason as above
    }

    // MARK: - Rate limiting
    
    /**
     The Imgur API limits the number of HTTP `POST` requests across all endpoints made from each IP address.
     */
    public struct PostLimit {
        public let allocation: Int
        public let remaining: Int
        public let timeUntilReset: TimeInterval
    }
    
    /**
     The Imgur API limits use of certain endpoints at both the client level (your API key, a.k.a. your application as registered with Imgur) and the user level (this particular IP address).
     
     There is a per-day client limit. In addition, if you exceed your per-day client limit five (?) times in a month, your API key is banned for the rest of the month.
     
     A suggestion: if `userRemaining` is `0`, you might show an error message saying "try again at `userResetDate`"; but if `clientRemaining` is `0`, your error message should just say "try again later".
     */
    public struct RateLimit: Decodable {
        public let clientAllocation: Int
        public let clientRemaining: Int
        // there’s no client reset date but it’s a "per day" thing (not sure what time zone)
        public let userAllocation: Int
        public let userRemaining: Int
        public let userResetDate: Date
        
        private enum CodingKeys: String, CodingKey {
            case clientAllocation = "ClientLimit"
            case clientRemaining = "ClientRemaining"
            case userAllocation = "UserLimit"
            case userRemaining = "UserRemaining"
            case userResetDate = "UserReset"
        }
    }

    /**
     Retrieve the Imgur API rate limit status for the current client (API key) and user (IP address).
     
     Note that each successful `upload(_:completion:)` call will also return rate limit status information. It may still be useful to specifically request rate limit status in order to avoid exceeding the client limits and getting banned for the month.
     
     This request does not use Imgur API rate limit credits.
     
     - Parameter completion: A closure to call once the request is completed. The closure is always called on the main queue.
     - Returns: A cancellable `Progress` instance.
     */
    @discardableResult
    public func checkRateLimitStatus(completion: @escaping (_ result: Result<RateLimit>) -> Void) -> Progress {
        let request = URLRequest(url: URL(string: "https://api.imgur.com/3/credits")!)
        let op = FetchURL<RateLimit>(urlSession: urlSession, request: request)
        log(.debug, "checking rate limit status")
        queue.addOperation(op)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling checking rate limit status")
            op.cancel()
        }

        let completionOp = BlockOperation {
            let result = op.result!
            log(.debug, "did check rate limit status with \(result)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(op)

        OperationQueue.main.addOperation(completionOp)

        return progress
    }

    // MARK: - Delete uploaded images

    /**
     Deletes a previously-uploaded image.
     
     Each successful call to an `upload(_:completion:)` method returns, among other info, a delete hash that can be used to delete the uploaded image.
     
     Deletion requests presumably use Imgur API rate limit credits, but this has not been tested.
     
     - Parameter deleteHash: Which photo to delete. (A `DeleteHash` is passed to the completion closure for each `upload(_:completion:)` method.)
     - Parameter completion: A closure to call once the request is complete. The closure is always called on the main queue.
     - Returns: A cancellable `Progress` instance.
     */
    @discardableResult
    public func delete(_ deleteHash: DeleteHash, completion: @escaping (_ result: Result<Void>) -> Void) -> Progress {
        let url = URL(string: "https://api.imgur.com/3/image/")!
            .appendingPathComponent(deleteHash.rawValue, isDirectory: false)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let op = FetchURL<Bool>(urlSession: urlSession, request: request)
        log(.debug, "deleting image with \(deleteHash)")
        queue.addOperation(op)

        let progress = Progress(totalUnitCount: 1)
        progress.cancellationHandler = {
            log(.debug, "cancelling deletion with \(deleteHash)")
            op.cancel()
        }

        let completionOp = BlockOperation {
            let result: Result<Void>
            switch op.result! {
            case .success:
                result = .success(())
            case .failure(let error):
                result = .failure(error)
            }

            log(.debug, "did delete image with \(deleteHash)")
            progress.completedUnitCount = 1
            completion(result)
        }
        completionOp.addDependency(op)

        OperationQueue.main.addOperation(completionOp)

        return progress
    }
    
    /**
     An opaque string value that can be passed back to Imgur via `delete(_:completion:)`.
     
     The Imgur documentation says these follow a particular format, but this struct doesn't bother trying to enforce that format.
     */
    public struct DeleteHash: RawRepresentable {
        public let rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

/**
 The documented file size limit for uploaded non-animated images.
 
 We have a couple of candidate sizes:
 
 * 10 MB, per https://api.imgur.com/endpoints/image#image-upload
 * 10 MB, per https://apidocs.imgur.com/#c85c9dfc-7487-4de2-9ecd-66f727cf3139
 * 20 MB, per https://help.imgur.com/hc/en-us/articles/115000083326
 
 There's also no mention of whether a megabyte is 2^20 bytes or 10^6 bytes.
 
 As of 2018-11-04, an 18.7 MB file was rejected with "File is over the size limit", so I guess that rules out 20 MB. And a 10,018,523 byte file was similarly rejected, so 10^7 it is!
 */
private let imgurFileSizeLimit = 10_000_000

internal func log(_ level: ImgurUploader.LogLevel, _ message: @autoclosure () -> String) {
    ImgurUploader.logger?(level, message)
}

internal typealias Result = ImgurUploader.Result
