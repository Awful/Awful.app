//  TextAttachment.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import Photos
import UIKit

private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier!, category: "Composition")

/**
    An enhanced text attachment that:
 
    * Negotiates reasonable image bounds with its text view.
    * Properly populates the image property after UIKit state restoration.
    * Uses the Photos framework for thumbnailing when possible.
    * Archives a compact copy of its image so draft autosaves stay cheap.
 */
final class TextAttachment: NSTextAttachment {
    
    // Would ideally be a `let` but see note at `init(data:ofType:)`.
    private(set) var photoAssetIdentifier: String?

    /// Bytes written into draft archives, so that autosaving never has to re-encode `image`.
    ///
    /// Asset-backed attachments store a thumbnail (the Photos asset is the source of truth and is
    /// reloaded at full size on decode); pasted images store the full-size image. Main-thread only.
    private var archivableImageData: Data?

    /// `true` while `prepareArchivableImageData()` is encoding on its background queue.
    private(set) var isPreparingArchivableImageData = false

    private static let encodingQueue = DispatchQueue(label: "com.awfulapp.Awful.TextAttachment.encoding", qos: .utility)
    
    init(image: UIImage, photoAssetIdentifier: String?) {
        self.photoAssetIdentifier = photoAssetIdentifier
        super.init(data: nil, ofType: nil)
        
        self.image = image
    }
    
    /*
     We've received crash logs indicting us for not implementing this initializer, and the backtrace indicated it can be called by `NSTextAttachment.init(coder:)`. So we need to implement it and forward to `super`.
     
     Annoyingly, we don't want to have to set `photoAssetIdentifier` here (because it'll already be set by our own `init(coder:)` implementation), so we have to make that property `var` to quiet the compiler.
     
     Not sure whether this is intended or documented behaviour for `NSTextAttachment`, though it does lead to some weirdness for Swift (e.g. we'd be required to set a value for any `let` property here, even if it was already set in our own `init(coder:)`, so what happens if you write twice to a `let`?)
     
     If it helps future explorers: as of writing, crash logs exist from iOS versions as late as 12.1.
     */
    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
    }
    
    required init?(coder: NSCoder) {
        let assetIdentifier = coder.decodeObject(of: NSString.self, forKey: CodingKeys.assetIdentifier.rawValue) as String?
        photoAssetIdentifier = assetIdentifier

        guard coder.containsValue(forKey: CodingKeys.formatVersion.rawValue) else {
            // Archive written by an older build via `NSTextAttachment`'s own coding.
            super.init(coder: coder)
            return
        }

        super.init(data: nil, ofType: nil)

        let storedData = coder.decodeObject(of: NSData.self, forKey: CodingKeys.imageData.rawValue) as Data?
        let storedImage = storedData.flatMap { UIImage(data: $0) }
        // Set `image` before seeding the cache: the setter clears it.
        image = assetIdentifier.flatMap(Self.fullSizeImage(forPhotoAssetIdentifier:)) ?? storedImage
        archivableImageData = storedData
    }
    
    override func encode(with coder: NSCoder) {
        // Deliberately not calling super: `NSTextAttachment` archives `image` itself, which for a
        // full-resolution photo means a PNG re-encode on every draft autosave.
        coder.encode(Self.currentFormatVersion, forKey: CodingKeys.formatVersion.rawValue)
        if let photoAssetIdentifier = photoAssetIdentifier {
            coder.encode(photoAssetIdentifier as NSString, forKey: CodingKeys.assetIdentifier.rawValue)
        }
        // The thumbnail fallback is at most 800x600, so it's cheap and guarantees the draft always
        // carries an image even if it's archived before the background encode finishes.
        if let data = archivableImageData ?? thumbnailImage?.jpegData(compressionQuality: 0.8) {
            coder.encode(data as NSData, forKey: CodingKeys.imageData.rawValue)
        }
    }

    private static let currentFormatVersion = 2
    
    private enum CodingKeys: String {
        case assetIdentifier
        case imageData = "AwfulImageData"
        case formatVersion = "AwfulFormatVersion"
    }

    /// Encodes the image for archiving on a background queue, once. Safe to call repeatedly.
    func prepareArchivableImageData(completion: (() -> Void)? = nil) {
        guard archivableImageData == nil, !isPreparingArchivableImageData, let image = image else {
            completion?()
            return
        }
        isPreparingArchivableImageData = true

        let isAssetBacked = photoAssetIdentifier != nil
        let source = isAssetBacked ? (thumbnailImage ?? image) : image
        let preferPNG = !isAssetBacked && image.hasAlphaChannel
        Self.encodingQueue.async {
            let data: Data? = autoreleasepool {
                preferPNG ? source.pngData() : source.jpegData(compressionQuality: isAssetBacked ? 0.8 : 0.9)
            }
            DispatchQueue.main.async { [weak self] in
                if let self {
                    self.isPreparingArchivableImageData = false
                    // Ignore the result if the image was swapped out meanwhile.
                    if self.image === image {
                        self.archivableImageData = data
                    }
                }
                completion?()
            }
        }
    }

    private static func fullSizeImage(forPhotoAssetIdentifier identifier: String) -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        var result: UIImage?
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
            result = image
        }
        return result
    }
    
    override var image: UIImage? {
        get {
            if let image = super.image {
                return image
            }
            
            guard let data = contents ?? fileWrapper?.regularFileContents else { return nil }
            let image = UIImage(data: data)
            self.image = image
            return image
        }
        set {
            super.image = newValue
            _thumbnailImage = nil
            archivableImageData = nil
        }
    }
    
    fileprivate var _thumbnailImage: UIImage?
    var thumbnailImage: UIImage? {
        if let thumbnail = _thumbnailImage { return thumbnail }
        guard let image = self.image else { return nil }
        let thumbnailSize = appropriateThumbnailSize(imageSize: image.size)
        if image.size == thumbnailSize {
            _thumbnailImage = image
            return image
        }

        let state = signposter.beginInterval("thumbnailImage")
        defer { signposter.endInterval("thumbnailImage", state) }
        
        if
            let photoAssetIdentifier = photoAssetIdentifier,
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photoAssetIdentifier], options: nil).firstObject
        {
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.resizeMode = .exact
            PHImageManager.default().requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFit, options: options, resultHandler: { (image, info) in
                self._thumbnailImage = image
            })
        }
        if let thumbnail = _thumbnailImage { return thumbnail }
        
        _thumbnailImage = image.thumbnail(targetSize: thumbnailSize)
        return _thumbnailImage
    }
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let size = thumbnailImage?.size ?? .zero
        return CGRect(origin: .zero, size: size)
    }
    
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        return thumbnailImage
    }
}

extension NSAttributedString {
    /// `true` while any `TextAttachment` is still encoding its bytes for archiving, i.e. a draft
    /// archived right now would carry only a thumbnail for it.
    var hasTextAttachmentsPreparingForArchive: Bool {
        var found = false
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: length)) { value, _, stop in
            if let attachment = value as? TextAttachment, attachment.isPreparingArchivableImageData {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

private func appropriateThumbnailSize(imageSize: CGSize) -> CGSize {
    let threshold = TextAttachment.requiresThumbnailImageSize
    let widthRatio = imageSize.width / threshold.width
    let heightRatio = imageSize.height / threshold.height
    let screenRatio = imageSize.width / (UIScreen.main.bounds.width - 8)
    let ratio = max(widthRatio, heightRatio, screenRatio)
    
    if ratio <= 1 { return imageSize }
    return CGSize(width: floor(imageSize.width / ratio), height: floor(imageSize.height / ratio))
}

private extension UIImage {
    func thumbnail(targetSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()!
    }

    var hasAlphaChannel: Bool {
        switch cgImage?.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast: return true
        default: return false
        }
    }
}

// This is only on a class (and then only computed) for Objective-C bridging.
extension TextAttachment {
    static var requiresThumbnailImageSize: CGSize {
        return CGSize(width: 800, height: 600)
    }
}
