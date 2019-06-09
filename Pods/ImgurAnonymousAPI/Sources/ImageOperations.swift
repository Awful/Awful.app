// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import Foundation
import ImageIO

internal struct ImageFile {
    let url: URL
}

internal enum ImageError: LocalizedError {
    case destinationCreationFailed
    case destinationFinalizationFailed
    case indeterminateOriginalFileSize
    case indeterminateThumbnailFileSize
    case missingCGImage
    case missingPhotoResource
    case sourceCreationFailed
    case thumbnailCreationFailed

    var errorDescription: String? {
        switch self {
        case .destinationCreationFailed:
            return "Could not make space to save resized image"
        case .destinationFinalizationFailed:
            return "Could not save resized image"
        case .indeterminateOriginalFileSize:
            return "Could not calculate original image file size"
        case .indeterminateThumbnailFileSize:
            return "Could not calculate resized image file size"
        case .missingCGImage:
            return "Original image is not a recognized format"
        case .missingPhotoResource:
            return "Could not find photo data"
        case .sourceCreationFailed:
            return "Could not find image"
        case .thumbnailCreationFailed:
            return "Could not resize image"
        }
    }
}

/**
 Ensures an image file is below a maximum file size threshold, resizing the image if necessary.
 
 The image is resized without being fully dragged into memory.
 */
internal final class ResizeImage: AsynchronousOperation<ImageFile> {
    
    private let maximumFileSizeBytes: Int
    
    init(maximumFileSizeBytes: Int) {
        self.maximumFileSizeBytes = maximumFileSizeBytes
    }
    
    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let originalImage = try firstDependencyValue(ofType: ImageFile.self)
        
        log(.debug, "someone wants to resize \(originalImage) in \(tempFolder)")
        
        guard let imageSource = CGImageSourceCreateWithURL(originalImage.url as CFURL, nil) else {
            throw ImageError.sourceCreationFailed
        }
        
        if let uti = CGImageSourceGetType(imageSource), UTTypeConformsTo(uti, kUTTypeGIF) {
            log(.debug, "original image is a GIF which we can't resize, so we'll just try the original")
            return finish(.success(originalImage))
        }

        guard let originalByteSize = try originalImage.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw ImageError.indeterminateOriginalFileSize
        }
        
        if originalByteSize <= maximumFileSizeBytes {
            log(.debug, "original image at \(originalByteSize) bytes is within the file size limit of \(maximumFileSizeBytes) so there's nothing to resize")
            return finish(.success(originalImage))
        } else {
            log(.debug, "original image is too large, will need to resize")
        }
        
        var maxPixelSize: Int
        if
            let properties = CGImageSourceCopyProperties(imageSource, nil) as NSDictionary?,
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        {
            maxPixelSize = max(width, height) / 2
        } else {
            maxPixelSize = 2048 // Gotta start somewhere.
        }

        var resizedImageURL = tempFolder.url
            .appendingPathComponent("resized", isDirectory: false)
            .appendingPathExtension(originalImage.url.pathExtension)
        
        while true {
            guard
                let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceShouldCache: false] as NSDictionary),
                let destination = CGImageDestinationCreateWithURL(resizedImageURL as CFURL, CGImageSourceGetType(imageSource) ?? kUTTypePNG, 1, nil) else
            {
                log(.error, "thumbnail creation failed")
                throw ImageError.thumbnailCreationFailed
            }

            CGImageDestinationAddImage(destination, thumbnail, nil)
            guard CGImageDestinationFinalize(destination) else {
                log(.error, "thumbnail could not be saved")
                throw ImageError.destinationFinalizationFailed
            }

            resizedImageURL.removeCachedResourceValue(forKey: .fileSizeKey)
            guard
                let resourceValues = try? resizedImageURL.resourceValues(forKeys: [.fileSizeKey]),
                let byteSize = resourceValues.fileSize else
            {
                log(.error, "could not determine file size of generated thumbnail")
                throw ImageError.indeterminateThumbnailFileSize
            }

            if byteSize <= maximumFileSizeBytes {
                log(.debug, "scaled image down to \(maxPixelSize)px as its larger dimension, which gets it to \(byteSize) bytes, which is within the file size limit")
                return finish(.success(ImageFile(url: resizedImageURL)))
            }
        }
    }
}

#if canImport(Photos)
import Photos

/// Retrieves image data for a `PHAsset` and saves it to a file in a temporary folder.
@available(macOS 10.13, tvOS 10.0, *)
internal final class SavePHAsset: AsynchronousOperation<ImageFile> {
    
    /// Returns `true` when the app has a photo library usage description and the user has authorized said access.
    static var hasRequiredPhotoLibraryAuthorization: Bool {
        
        // "Apps linked on or after iOS 10 will crash if [the NSPhotoLibraryUsageDescription] key is not present."
        if #available(iOS 10.0, *), Bundle.main.infoDictionary?["NSPhotoLibraryUsageDescription"] == nil {
            return false
        }

        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .denied, .notDetermined, .restricted:
            return false
        case .authorized:
            return true
        @unknown default:
            assertionFailure("handle unknown photo library authorization status: \(status.rawValue)")
            return false
        }
    }
    
    private let asset: PHAsset

    init(_ asset: PHAsset) {
        self.asset = asset
    }

    override func execute() throws {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)

        let resources = PHAssetResource.assetResources(for: asset)
        guard
            let photo = resources.first(where: { $0.type == .fullSizePhoto })
                ?? resources.first(where: { $0.type == .photo })
            else { throw ImageError.missingPhotoResource }

        let imageURL: URL = {
            if photo.originalFilename.isEmpty {
                let ext = UTTypeCopyPreferredTagWithClass(photo.uniformTypeIdentifier as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as String? ?? "jpg"
                return tempFolder.url
                    .appendingPathComponent("original", isDirectory: false)
                    .appendingPathExtension(ext)
            } else {
                return tempFolder.url
                    .appendingPathComponent(photo.originalFilename, isDirectory: false)
            }
        }()

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        log(.debug, "saving \(asset) to \(imageURL)")
        PHAssetResourceManager.default().writeData(for: photo, toFile: imageURL, options: options, completionHandler: { error in
            if let error = error {
                self.finish(.failure(error))
            } else {
                self.finish(.success(ImageFile(url: imageURL)))
            }
        })
    }
}

#endif

#if canImport(UIKit)
import MobileCoreServices
import UIKit

/// Writes the image data to file in a temporary folder.
internal final class SaveUIImage: AsynchronousOperation<ImageFile> {
    private let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }

    override func execute() throws {
        let imageURL: URL
        if let images = image.images, images.count > 1 {
            imageURL = try saveAnimated(frames: images)
        } else {
            imageURL = try saveStatic()
        }
        finish(.success(ImageFile(url: imageURL)))
    }
    
    private func saveAnimated(frames: [UIImage]) throws -> URL {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageURL = tempFolder.url.appendingPathComponent("original.gif", isDirectory: false)
        
        guard let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, kUTTypeGIF, frames.count, nil) else {
            throw ImageError.destinationCreationFailed
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0]] as [AnyHashable: Any] as CFDictionary)
        
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: image.duration / Double(frames.count)] as [AnyHashable: Any]] as CFDictionary
        
        for frame in frames {
            guard let cgImage = frame.cgImage else {
                throw ImageError.missingCGImage
            }
            CGImageDestinationAddImage(destination, cgImage, frameProperties)
        }
        
        log(.debug, "saving \(image) to \(imageURL)")
        CGImageDestinationFinalize(destination)
        
        return imageURL
    }
    
    private func saveStatic() throws -> URL {
        let tempFolder = try firstDependencyValue(ofType: TemporaryFolder.self)
        let imageURL = tempFolder.url.appendingPathComponent("original.tiff", isDirectory: false)

        guard let cgImage = image.cgImage else {
            throw ImageError.missingCGImage
        }

        // Save as TIFF here to preserve orientation data (unlike PNG) with lossless image data (unlike JPEG).
        guard let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, kUTTypeTIFF, 1, nil) else {
            throw ImageError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, cgImage, {
            var options: [AnyHashable: Any] = [
                kCGImagePropertyHasAlpha: true,
                kCGImagePropertyOrientation: image.imageOrientation.cgOrientation.rawValue]

            if #available(iOS 9.3, tvOS 9.3, watchOS 2.3, *) {
                options[kCGImageDestinationOptimizeColorForSharing] = true
            }

            return options as NSDictionary
        }())

        log(.debug, "saving \(image) to \(imageURL)")
        CGImageDestinationFinalize(destination)

        return imageURL
    }
}

private extension UIImage.Orientation {
    
    /// `UIImage.Orientation` and `CGImagePropertyOrientation` don't have the same raw values.
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            fatalError("handle unknown UIImage orientation: \(self.rawValue)")
        }
    }
}

#endif
