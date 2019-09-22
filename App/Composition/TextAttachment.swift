//  TextAttachment.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos
import UIKit

/**
    An enhanced text attachment that:
 
    * Negotiates reasonable image bounds with its text view.
    * Properly populates the image property after UIKit state resotration.
    * Uses the Photos framework for thumbnailing when possible.
 */
final class TextAttachment: NSTextAttachment {
    
    // Would ideally be a `let` but see note at `init(data:ofType:)`.
    private(set) var photoAssetIdentifier: String?
    
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
        if let photoAssetIdentifier = coder.decodeObject(of: NSString.self, forKey: CodingKeys.assetIdentifier.rawValue) {
            self.photoAssetIdentifier = photoAssetIdentifier as String
        }
        
        super.init(coder: coder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        if let photoAssetIdentifier = photoAssetIdentifier {
            coder.encode(photoAssetIdentifier as NSString, forKey: CodingKeys.assetIdentifier.rawValue)
        }
    }
    
    private enum CodingKeys: String {
        case assetIdentifier
    }
    
    private enum ObsoleteCodingKeys: String {
        case assetURL = "AwfulAssetURL"
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
        }
    }
    
    fileprivate var _thumbnailImage: UIImage?
    var thumbnailImage: UIImage? {
        if let thumbnail = _thumbnailImage { return thumbnail }
        guard let image = self.image else { return nil }
        let thumbnailSize = appropriateThumbnailSize(imageSize: image.size)
        if image.size == thumbnailSize { return image }
        
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

private let assetURLKey = "AwfulAssetURL"

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
}

// This is only on a class (and then only computed) for Objective-C bridging.
extension TextAttachment {
    static var requiresThumbnailImageSize: CGSize {
        return CGSize(width: 800, height: 600)
    }
}
