//  NamedThreadTag.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics
import NukeExtensions

/// A thread tag that will be loaded by a cell when configured, but in the meantime knows its size.
enum NamedThreadTag {
    case none
    case spacer
    case image(name: String?, placeholder: ThreadTagLoader.Placeholder)
    
    var imageName: String? {
        switch self {
        case .image(name: let name, placeholder: _):
            return name
        case .none, .spacer:
            return nil
        }
    }
    
    var imageSize: CGSize {
        switch self {
        case .image, .spacer:
            return CGSize(width: 45, height: 45)
        case .none:
            return .zero
        }
    }
    
    var placeholder: ThreadTagLoader.Placeholder? {
        switch self {
        case .image(name: _, placeholder: let placeholder):
            return placeholder
        case .none, .spacer:
            return nil
        }
    }
}

extension ThreadTagLoader {
    @MainActor
    func loadNamedImage(_ tag: NamedThreadTag, into imageView: ImageDisplayingView) {
        loadImage(named: tag.imageName, placeholder: tag.placeholder, into: imageView)
    }
}
