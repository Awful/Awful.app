//  ThreadTagLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Crashlytics
import Nuke
import PromiseKit
import UIKit

private let Log = Logger.get(level: .debug)

/**
 Loads and caches thread tag images.
 
 Awful ships with many thread tag images, but we also want new ones to appear in the app without requiring a full app update. In addition, we want any images to be returned for efficient use on the main thread. Finally, it's nice to deduplicate requests for the same tag image. All that happens here.
 */
final class ThreadTagLoader {
    
    /// Loads a thread tag image directly into an image view.
    func loadImage(
        named imageName: String?,
        placeholder: Placeholder?,
        into view: ImageDisplayingView,
        completion: ImageTask.Completion? = nil)
    {
        guard let imageName = imageName, let url = makeURLForImage(named: imageName) else {
            cancelRequest(for: view)
            view.display(image: placeholder?.image)
            return
        }
        
        var options = ImageLoadingOptions(placeholder: placeholder?.image)
        options.pipeline = pipeline
        Nuke.loadImage(with: url, options: options, into: view, completion: { response, error in
            self.recordMissingTagImage(named: imageName, response: response, error: error)
            completion?(response, error)
        })
    }
    
    func cancelRequest(for view: ImageDisplayingView) {
        Nuke.cancelRequest(for: view)
    }
    
    func loadImage(named imageName: String?, completion: @escaping ImageTask.Completion) -> ImageTask? {
        guard let imageName = imageName, let url = makeURLForImage(named: imageName) else {
            completion(nil, .dataLoadingFailed(CocoaError(.fileNoSuchFile)))
            return nil
        }
        
        return pipeline.loadImage(with: url, completion: { response, error in
            self.recordMissingTagImage(named: imageName, response: response, error: error)
            completion(response, error)
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
    
    private func recordMissingTagImage(named imageName: String, response: ImageResponse?, error: ImagePipeline.Error?) -> Void
    {
        if
            let error = error,
            case .dataLoadingFailed(let underlyingError) = error,
            case .statusCodeUnacceptable(let statusCode)? = underlyingError as? DataLoader.Error,
            statusCode == 404
        {
            Log.i("missing thread tag image: \(imageName)")
            Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: ["imageName": imageName])
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
        let pipeline = ImagePipeline(configuration: .init(dataLoader: dataLoader, imageCache: ImageCache.shared))
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
            return Placeholder(imageName: "empty-thread-tag", tintColor: tintColor)
        }
        
        static func thread(in forum: Forum) -> Placeholder {
            return Placeholder(
                imageName: "empty-thread-tag",
                tintColor: Theme.currentThemeForForum(forum: forum)["listTextColor"])
        }
        
        
        private let imageName: String
        private let tintColor: UIColor?
        
        var image: UIImage? {
            let image = UIImage(named: imageName)
            return tintColor.flatMap { image?.withTint($0) } ?? image
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
