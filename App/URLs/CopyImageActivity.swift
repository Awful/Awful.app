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

    override var activityType: UIActivity.ActivityType {
        .init("com.awfulapp.Awful.CopyImage")
    }

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
        image = activityItems.lazy.compactMap { (item: Any) -> Image? in
            switch item {
            case let data as Data:
                guard let uti = imageUTI(data) else { return nil }
                return .data(data, uti)
            case let image as UIImage:
                return .ui(image)
            default:
                return nil
            }
        }.first { _ in true }
    }

    override func perform() {
        switch image {
        case let .data(data, uti):
            UIPasteboard.general.setData(data, forPasteboardType: uti.identifier)
        case let .ui(image):
            UIPasteboard.general.image = image
        case nil:
            break
        }

        activityDidFinish(true)
    }
}

private func isImage(_ data: Data) -> Bool {
    guard let type = imageUTI(data) else { return false }
    return type.conforms(to: .image)
}

private func imageUTI(_ data: Data) -> UTType? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [
        kCGImageSourceShouldCache: false
    ] as CFDictionary) else { return nil }
    return CGImageSourceGetType(source).flatMap { UTType($0 as String) }
}
