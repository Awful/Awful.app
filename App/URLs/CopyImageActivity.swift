//  CopyImageActivity.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreServices
import ImageIO
import UIKit
import UniformTypeIdentifiers

final class CopyImageActivity: UIActivity {

    private var image: Image?

    private enum Image {
        case data(Data, UTType)
        case ui(UIImage)
    }

    // MARK: UIActivity

    static let activityType = UIActivity.ActivityType("com.awfulapp.Awful.CopyImage")
    override var activityType: UIActivity.ActivityType { Self.activityType }

    override class var activityCategory: UIActivity.Category { .action }

    override var activityTitle: String? {
        LocalizedString("link-action.copy-image")
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "doc.on.doc")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains {
            switch $0 {
            case let data as Data:
                return isImage(data)
            case is UIImage:
                return true
            default:
                return false
            }
        }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        // Prefer the original bytes over a decoded UIImage whatever order the items arrive in (the Mac share sheet doesn't keep ours), since a UIImage of a GIF is just its first frame.
        let candidates = activityItems.compactMap { (item: Any) -> Image? in
            switch item {
            case let data as Data:
                guard let uti = imageUTI(data) else { return nil }
                return .data(data, uti)
            case let image as UIImage:
                return .ui(image)
            default:
                return nil
            }
        }
        image = candidates.first { if case .data = $0 { return true } else { return false } } ?? candidates.first
    }

    override func perform() {
        switch image {
        case let .data(data, _):
            _ = copyImageToPasteboard(data)
        case let .ui(image):
            UIPasteboard.general.image = image
        case nil:
            break
        }

        activityDidFinish(true)
    }
}

/// Puts the image on the pasteboard in its original format, with a PNG rendering alongside for apps that only take still images. The original is registered first so apps that can handle it (an animated GIF, say) prefer it. Returns false when the data isn't an image.
func copyImageToPasteboard(_ data: Data) -> Bool {
    guard let uti = imageUTI(data), uti.conforms(to: .image) else { return false }

    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: uti.identifier, visibility: .all) { completion in
        completion(data, nil)
        return nil
    }
    if uti != .png, let png = UIImage(data: data)?.pngData() {
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(png, nil)
            return nil
        }
    }
    UIPasteboard.general.setItemProviders([provider], localOnly: false, expirationDate: nil)
    return true
}

private func isImage(_ data: Data) -> Bool {
    guard let type = imageUTI(data) else { return false }
    return type.conforms(to: .image)
}

/// The image type of the data, or nil when it isn't an image ImageIO knows.
func imageUTI(_ data: Data) -> UTType? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [
        kCGImageSourceShouldCache: false
    ] as CFDictionary) else { return nil }
    return CGImageSourceGetType(source).flatMap { UTType($0 as String) }
}
