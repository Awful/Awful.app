//  ForumAttachment.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import Photos
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumAttachment")

/**
 Represents an image attachment for a forum post with validation and compression capabilities.

 `ForumAttachment` handles image validation, resizing, and compression to meet forum requirements.
 It supports both direct image instances and photo library assets, with automatic validation
 against file size and dimension limits.

 ## Validation Rules

 Attachments are validated against:
 - Maximum file size: 2 MB (2,097,152 bytes)
 - Maximum dimensions: 4096×4096 pixels
 - Supported formats: GIF, JPEG, PNG

 ## Resizing and Compression

 When an image exceeds limits, `ForumAttachment` can automatically:
 1. Scale down dimensions while maintaining aspect ratio
 2. Apply progressive JPEG compression (for non-transparent images)
 3. Scale down PNG images with transparency until they meet size requirements

 ## State Preservation

 Conforms to `NSCoding` to support UIKit state restoration. Photo library assets are
 stored by identifier and reloaded on restoration.
 */
public final class ForumAttachment: NSObject, NSCoding {

    public static let maxFileSize = 2_097_152
    public static let maxDimension = 4096
    public static let supportedExtensions = ["gif", "jpg", "jpeg", "png"]

    private struct CompressionSettings {
        /// Initial JPEG compression quality (0.9 provides good balance between file size and visual quality)
        static let defaultQuality: CGFloat = 0.9
        /// Amount to reduce quality on each compression iteration (0.1 provides smooth quality degradation)
        static let qualityDecrement: CGFloat = 0.1
        /// Minimum acceptable JPEG quality before switching to dimension reduction (0.1 prevents over-compression artifacts)
        static let minQuality: CGFloat = 0.1
        /// Factor to scale down dimensions for PNG images with alpha (0.9 provides gradual size reduction)
        static let dimensionScaleFactor: CGFloat = 0.9
        /// Minimum image dimension to maintain readability (100px ensures text/details remain visible)
        static let minimumDimension = 100
    }

    public let image: UIImage?
    public let photoAssetIdentifier: String?
    public private(set) var validationError: ValidationError?

    public enum ValidationError: Error {
        case fileTooLarge(actualSize: Int, maxSize: Int)
        case dimensionsTooLarge(width: Int, height: Int, maxDimension: Int)
        case unsupportedFormat
        case imageDataConversionFailed
    }

    public init(image: UIImage, photoAssetIdentifier: String? = nil) {
        self.image = image
        self.photoAssetIdentifier = photoAssetIdentifier
        super.init()
        self.validationError = validate()
    }

    public required init?(coder: NSCoder) {
        if let photoAssetIdentifier = coder.decodeObject(of: NSString.self, forKey: CodingKeys.assetIdentifier.rawValue) {
            self.photoAssetIdentifier = photoAssetIdentifier as String

            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photoAssetIdentifier as String], options: nil).firstObject {
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                options.deliveryMode = .highQualityFormat
                var resultImage: UIImage?
                var requestError: Error?
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, info in
                    resultImage = image
                    if let error = info?[PHImageErrorKey] as? Error {
                        requestError = error
                    }
                }

                if let error = requestError {
                    logger.error("Failed to load image from photo library asset: \(error.localizedDescription)")
                } else if resultImage == nil {
                    logger.error("Photo library request returned nil image for asset: \(photoAssetIdentifier as String)")
                }

                self.image = resultImage
            } else {
                logger.error("Photo asset not found for identifier: \(photoAssetIdentifier as String)")
                self.image = nil
            }
        } else if let imageData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.imageData.rawValue) {
            self.image = UIImage(data: imageData as Data)
            self.photoAssetIdentifier = nil
        } else {
            return nil
        }

        super.init()
        self.validationError = validate()
    }

    public func encode(with coder: NSCoder) {
        if let photoAssetIdentifier = photoAssetIdentifier {
            coder.encode(photoAssetIdentifier as NSString, forKey: CodingKeys.assetIdentifier.rawValue)
        } else if let image = image, let imageData = image.pngData() {
            coder.encode(imageData as NSData, forKey: CodingKeys.imageData.rawValue)
        }
    }

    private enum CodingKeys: String {
        case assetIdentifier
        case imageData
    }

    public var isValid: Bool {
        return validationError == nil
    }

    public func validate(maxFileSize: Int? = nil, maxDimension: Int? = nil) -> ValidationError? {
        guard let image = image else {
            return .imageDataConversionFailed
        }

        let effectiveMaxDimension = maxDimension ?? Self.maxDimension
        let effectiveMaxFileSize = maxFileSize ?? Self.maxFileSize

        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        if width > effectiveMaxDimension || height > effectiveMaxDimension {
            return .dimensionsTooLarge(width: width, height: height, maxDimension: effectiveMaxDimension)
        }

        do {
            let (data, _, _) = try imageData()
            if data.count > effectiveMaxFileSize {
                return .fileTooLarge(actualSize: data.count, maxSize: effectiveMaxFileSize)
            }
        } catch {
            logger.error("Failed to convert image to data during validation: \(error)")
            return .imageDataConversionFailed
        }

        return nil
    }

    public func imageData() throws -> (data: Data, filename: String, mimeType: String) {
        guard let image = image else {
            throw ValidationError.imageDataConversionFailed
        }

        let hasAlpha = image.hasAlpha
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        if hasAlpha, let pngData = image.pngData() {
            return (pngData, "photo-\(timestamp).png", "image/png")
        } else if let jpegData = image.jpegData(compressionQuality: CompressionSettings.defaultQuality) {
            return (jpegData, "photo-\(timestamp).jpg", "image/jpeg")
        } else {
            throw ValidationError.imageDataConversionFailed
        }
    }

    public func resized(maxDimension: Int? = nil, maxFileSize: Int? = nil) -> ForumAttachment? {
        guard let originalImage = image else { return nil }

        let effectiveMaxDimension = maxDimension ?? Self.maxDimension
        let effectiveMaxFileSize = maxFileSize ?? Self.maxFileSize

        let originalWidth = Int(originalImage.size.width * originalImage.scale)
        let originalHeight = Int(originalImage.size.height * originalImage.scale)

        var targetWidth = originalWidth
        var targetHeight = originalHeight

        if originalWidth > effectiveMaxDimension || originalHeight > effectiveMaxDimension {
            let ratio = min(CGFloat(effectiveMaxDimension) / CGFloat(originalWidth),
                          CGFloat(effectiveMaxDimension) / CGFloat(originalHeight))
            targetWidth = Int(CGFloat(originalWidth) * ratio)
            targetHeight = Int(CGFloat(originalHeight) * ratio)
        }

        if let compressed = compressImage(
            originalImage,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            maxFileSize: effectiveMaxFileSize
        ) {
            return ForumAttachment(image: compressed, photoAssetIdentifier: photoAssetIdentifier)
        }

        return nil
    }

    private func compressImage(
        _ originalImage: UIImage,
        targetWidth: Int,
        targetHeight: Int,
        maxFileSize: Int
    ) -> UIImage? {
        var compressionQuality = CompressionSettings.defaultQuality
        var currentWidth = targetWidth
        var currentHeight = targetHeight
        var resizedImage = originalImage.resized(to: CGSize(width: currentWidth, height: currentHeight))

        while compressionQuality > CompressionSettings.minQuality {
            let hasAlpha = resizedImage.hasAlpha
            let data: Data?

            if hasAlpha {
                data = resizedImage.pngData()
            } else {
                data = resizedImage.jpegData(compressionQuality: compressionQuality)
            }

            if let imageData = data, imageData.count <= maxFileSize {
                return resizedImage
            }

            if hasAlpha {
                let newWidth = Int(CGFloat(currentWidth) * CompressionSettings.dimensionScaleFactor)
                let newHeight = Int(CGFloat(currentHeight) * CompressionSettings.dimensionScaleFactor)
                if newWidth < CompressionSettings.minimumDimension || newHeight < CompressionSettings.minimumDimension { break }
                currentWidth = newWidth
                currentHeight = newHeight
                resizedImage = originalImage.resized(to: CGSize(width: currentWidth, height: currentHeight))
            } else {
                compressionQuality -= CompressionSettings.qualityDecrement
            }
        }

        return nil
    }
}

extension ForumAttachment.ValidationError {
    public var localizedDescription: String {
        switch self {
        case .fileTooLarge(let actualSize, let maxSize):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "File size (\(formatter.string(fromByteCount: Int64(actualSize)))) exceeds maximum (\(formatter.string(fromByteCount: Int64(maxSize))))"
        case .dimensionsTooLarge(let width, let height, let maxDimension):
            return "Image dimensions (\(width)×\(height)) exceed maximum (\(maxDimension)×\(maxDimension))"
        case .unsupportedFormat:
            return "Unsupported image format. Supported formats: GIF, JPEG, PNG"
        case .imageDataConversionFailed:
            return "Failed to process image data"
        }
    }
}

private extension UIImage {
    private static let alphaInfoTypes: Set<CGImageAlphaInfo> = [.first, .last, .premultipliedFirst, .premultipliedLast]

    var hasAlpha: Bool {
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        return Self.alphaInfoTypes.contains(alphaInfo)
    }

    func resized(to targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
