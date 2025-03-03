//  ThreadTagLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulTheming
import Nuke
import NukeExtensions
import os
import UIKit

import enum Swift.Result

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ThreadTagLoader")

/**
 Loads and caches thread tag images.
 
 Awful ships with many thread tag images, but we also want new ones to appear in the app without requiring a full app update. In addition, we want any images to be returned for efficient use on the main thread. Finally, it's nice to deduplicate requests for the same tag image. All that happens here.
 */
final class ThreadTagLoader {
    
    /// Loads a thread tag image directly into an image view.
    @MainActor
    func loadImage(
        named imageName: String?,
        placeholder: Placeholder?,
        into view: ImageDisplayingView,
        completion: @escaping (_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void = { _ in }
    ) {
        guard let imageName = imageName, let url = makeURLForImage(named: imageName) else {
            cancelRequest(for: view)
            view.nuke_display(image: placeholder?.image, data: nil)
            return
        }
        
        var options = ImageLoadingOptions(placeholder: placeholder?.image)
        options.pipeline = pipeline
        NukeExtensions.loadImage(with: url, options: options, into: view, completion: { result in
            self.recordMissingTagImage(named: imageName, result)
            completion(result)
        })
    }
    
    @MainActor
    func cancelRequest(for view: ImageDisplayingView) {
        NukeExtensions.cancelRequest(for: view)
    }
    
    func loadImage(
        named imageName: String?,
        completion: @escaping (_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void
    ) -> ImageTask? {
        guard let imageName = imageName, let url = makeURLForImage(named: imageName) else {
            completion(.failure(.dataLoadingFailed(error: CocoaError(.fileNoSuchFile))))
            return nil
        }
        
        return pipeline.loadImage(with: url, completion: { result in
            self.recordMissingTagImage(named: imageName, result)
            completion(result)
        })
    }
    
    private func makeURLForImage(named imageName: String) -> URL? {
        var imageName = imageName
        if let i = imageName.lastIndex(of: ".") {
            imageName.removeSubrange(i...)
        }
        
        return baseURL
            .appendingPathComponent(imageName, isDirectory: false)
            .appendingPathExtension("png")
    }
    
    private func recordMissingTagImage(
        named imageName: String,
        _ result: Result<ImageResponse, ImagePipeline.Error>
    ) -> Void {
        if
            case .failure(let error) = result,
            case .dataLoadingFailed(let underlyingError) = error,
            case .statusCodeUnacceptable(let statusCode)? = underlyingError as? DataLoader.Error,
            statusCode == 404
        {
            logger.info("missing thread tag image: \(imageName)")
        }
    }
    
    static let shared: ThreadTagLoader = {
        let bundle = Bundle(for: ThreadTagLoader.self)
        let baseURL = URL(string: bundle.object(forInfoDictionaryKey: "AwfulThreadTagImageBaseURL") as! String)!
        let objectionableImageNames: Set<String> = {
            let url = bundle.url(forResource: "PotentiallyObjectionableThreadTags", withExtension: "plist")!
            let stream = InputStream(url: url)!
            stream.open()
            let imageNamesArray = try! PropertyListSerialization.propertyList(with: stream, format: nil) as! [String]
            stream.close()
            return Set(imageNamesArray)
        }()
        let dataLoader = ThreadTagDataLoader(bundle: bundle, objectionableImageNames: objectionableImageNames, fallback: DataLoader())
        let pipeline = ImagePipeline(configuration: .init(dataLoader: dataLoader))
        return ThreadTagLoader(baseURL: baseURL, pipeline: pipeline)
    }()
    
    private let baseURL: URL
    private let pipeline: ImagePipeline
    
    private init(baseURL: URL, pipeline: ImagePipeline) {
        self.baseURL = baseURL
        self.pipeline = pipeline
    }
}

extension ThreadTagLoader {
    struct Placeholder {
        
        static let noFilter = Placeholder(imageName: "no-filter-icon", tintColor: nil)
        static let privateMessage = Placeholder(imageName: "empty-pm-tag", tintColor: nil)
        
        static func thread(tintColor: UIColor?) -> Placeholder {
            return Placeholder(imageName: "empty-thread-tag", tintColor: nil)
        }
        
        static func thread(in forum: Forum) -> Placeholder {
            return Placeholder(
                imageName: "empty-thread-tag",
                tintColor: Theme.currentTheme(for: ForumID(forum.forumID))["listTextColor"])
        }
        
        
        private let imageName: String
        private let tintColor: UIColor?

        var image: UIImage? {
            if imageName == "empty-thread-tag" {
                let image = UIImage(named: imageName)!
                    .withRenderingMode(.alwaysTemplate)
                    .withTintColor(Theme.defaultTheme()["tintColor"]!)
                
                let backgroundImage = UIImage(named: "thread-tag-background")!
                    .withRenderingMode(.alwaysTemplate)
                    .withTintColor(Theme.defaultTheme()["backgroundColor"]!)
                
                let borderImage = UIImage(named: "thread-tag-border")!
                    .withRenderingMode(.alwaysTemplate)
                    .withTintColor(Theme.defaultTheme()["listSecondaryTextColor"]!)
                
                let finalImage = backgroundImage
                    .mergeWith(topImage: image)
                    .mergeWith(topImage: borderImage)
                    
                return finalImage
            } else if imageName == "empty-pm-tag" {
                let image = UIImage(named: imageName)!
                    .withRenderingMode(.alwaysTemplate)
                    .withTintColor(Theme.defaultTheme()["listSecondaryTextColor"]!)
                
                let backgroundImage = UIImage(named: "thread-tag-background")!
                    .withRenderingMode(.alwaysTemplate)
                    .withTintColor(Theme.defaultTheme()["backgroundColor"]!)
                
                let borderImage = UIImage(named: "thread-tag-border")!
                    .withRenderingMode(.alwaysTemplate)
                    .withTintColor(Theme.defaultTheme()["listSecondaryTextColor"]!)
                
                let finalImage = backgroundImage
                    .mergeWith(topImage: image)
                    .mergeWith(topImage: borderImage)
                    
                return finalImage
            } else {
                let image = UIImage(named: imageName)
                return image
            }
        }
    }
}

enum NamedThreadTagImage {
    case none
    case spacer
    case image(name: String)
    
    var imageName: String? {
        switch self {
        case .image(name: let name): return name
        case .none, .spacer: return nil
        }
    }
    
    var imageSize: CGSize {
        switch self {
        case .image, .spacer: return CGSize(width: 45, height: 45)
        case .none: return .zero
        }
    }
}
