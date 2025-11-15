//  ForumAttachment.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos
import UIKit

final class ForumAttachment: NSObject, NSCoding {

    static let maxFileSize = 2_097_152
    static let maxDimension = 4096
    static let supportedExtensions = ["gif", "jpg", "jpeg", "png"]

    let image: UIImage?
    let photoAssetIdentifier: String?
    private(set) var validationError: ValidationError?

    enum ValidationError: Error {
        case fileTooLarge(actualSize: Int, maxSize: Int)
        case dimensionsTooLarge(width: Int, height: Int, maxDimension: Int)
        case unsupportedFormat
        case imageDataConversionFailed
    }

    init(image: UIImage, photoAssetIdentifier: String? = nil) {
        self.image = image
        self.photoAssetIdentifier = photoAssetIdentifier
        super.init()
        self.validationError = performValidation()
    }

    required init?(coder: NSCoder) {
        if let photoAssetIdentifier = coder.decodeObject(of: NSString.self, forKey: CodingKeys.assetIdentifier.rawValue) {
            self.photoAssetIdentifier = photoAssetIdentifier as String

            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photoAssetIdentifier as String], options: nil).firstObject {
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                options.deliveryMode = .highQualityFormat
                var resultImage: UIImage?
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                    resultImage = image
                }
                self.image = resultImage
            } else {
                self.image = nil
            }
        } else if let imageData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.imageData.rawValue) {
            self.image = UIImage(data: imageData as Data)
            self.photoAssetIdentifier = nil
        } else {
            return nil
        }

        super.init()
        self.validationError = performValidation()
    }

    func encode(with coder: NSCoder) {
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

    var isValid: Bool {
        return validationError == nil
    }

    func validate(maxFileSize: Int? = nil, maxDimension: Int? = nil) -> ValidationError? {
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
            return .imageDataConversionFailed
        }

        return nil
    }

    private func performValidation() -> ValidationError? {
        return validate()
    }

    func imageData() throws -> (data: Data, filename: String, mimeType: String) {
        guard let image = image else {
            throw ValidationError.imageDataConversionFailed
        }

        let hasAlpha = image.hasAlpha
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        if hasAlpha, let pngData = image.pngData() {
            return (pngData, "photo-\(timestamp).png", "image/png")
        } else if let jpegData = image.jpegData(compressionQuality: 0.9) {
            return (jpegData, "photo-\(timestamp).jpg", "image/jpeg")
        } else {
            throw ValidationError.imageDataConversionFailed
        }
    }

    func resized(maxDimension: Int? = nil, maxFileSize: Int? = nil) -> ForumAttachment? {
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

        var compressionQuality: CGFloat = 0.9
        var resizedImage = originalImage.resized(to: CGSize(width: targetWidth, height: targetHeight))

        while compressionQuality > 0.1 {
            let hasAlpha = resizedImage.hasAlpha
            let data: Data?

            if hasAlpha {
                data = resizedImage.pngData()
            } else {
                data = resizedImage.jpegData(compressionQuality: compressionQuality)
            }

            if let imageData = data, imageData.count <= effectiveMaxFileSize {
                return ForumAttachment(image: resizedImage, photoAssetIdentifier: photoAssetIdentifier)
            }

            if hasAlpha {
                let newWidth = Int(CGFloat(targetWidth) * 0.9)
                let newHeight = Int(CGFloat(targetHeight) * 0.9)
                if newWidth < 100 || newHeight < 100 { break }
                targetWidth = newWidth
                targetHeight = newHeight
                resizedImage = originalImage.resized(to: CGSize(width: targetWidth, height: targetHeight))
            } else {
                compressionQuality -= 0.1
            }
        }

        return nil
    }
}

extension ForumAttachment.ValidationError {
    var localizedDescription: String {
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
    var hasAlpha: Bool {
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        return alphaInfo == .first || alphaInfo == .last || alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast
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
