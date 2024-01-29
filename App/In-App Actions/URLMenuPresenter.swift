//  URLMenuPresenter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import Smilies
import UIKit
import Photos
import MRProgress

private let Log = Logger.get()

private enum _URLMenuPresenter {
    case link(url: URL, imageURL: URL?, smilie: PostedSmilie?)
    case video(url: URL)
    
    func presentInDefaultBrowser(fromViewController presenter: UIViewController) {
        let url: URL
        switch self {
        case .link(url: let linkURL, _, _):
            url = linkURL
        case .video(let rawURL):
            if let videoURL = VideoURL(rawURL) {
                url = videoURL.unembeddedURL
            } else {
                url = rawURL
            }
        }
        
        if canOpenInYouTube(url), FoilDefaultStorage(Settings.openYouTubeLinksInYouTube).wrappedValue {
            UIApplication.shared.open(url)
            return
        }
        
        if canOpenInTwitter(url), FoilDefaultStorage(Settings.openTwitterLinksInTwitter).wrappedValue {
            UIApplication.shared.open(url)
            return
        }
        
        if canOpenInVLC(url) {
            let vlcURL = URL(string: "vlc://\(url.host!)\(url.path)")!
            UIApplication.shared.open(vlcURL)
            return
        }
        
        switch FoilDefaultStorage(Settings.defaultBrowser).wrappedValue {
        case .awful:
            AwfulBrowser.presentBrowserForURL(url, fromViewController: presenter)
        case .defaultiOSBrowser:
            UIApplication.shared.open(url)
        case .brave:
            UIApplication.shared.open(bravifyURL(url))
        case .chrome:
            UIApplication.shared.open(chromifyURL(url))
        case .edge:
            UIApplication.shared.open(edgifyURL(url))
        case .firefox:
            UIApplication.shared.open(firefoxifyURL(url))
        }
    }
    
    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: UIView) {
        var actions: [UIAlertAction] = []
        let title: String?
        let message: String?
        switch self {
        case let .link(url: linkURL, imageURL: imageURL, smilie: smilie):
            title = linkURL.absoluteString

            let browsers = DefaultBrowser.installedBrowsers
            let isHTTP = ["http", "https"].contains((linkURL.scheme ?? "").lowercased())
            let route = try? AwfulRoute(linkURL)
            
            if browsers.contains(.awful) && (route != nil || isHTTP) {
                actions.append(.default(title: LocalizedString("link-action.open-in-awful")) {
                    if let route = try? AwfulRoute(linkURL) {
                        AppDelegate.instance.open(route: route)
                    } else {
                        AwfulBrowser.presentBrowserForURL(linkURL, fromViewController: presenter)
                    }
                })
            }
            
            if browsers.contains(.defaultiOSBrowser) {
                let title: String
                if canOpenInYouTube(linkURL) {
                    title = LocalizedString("link-action.open-in-youtube")
                } else if canOpenInTwitter(linkURL) {
                    title = LocalizedString("link-action.open-in-twitter")
                } else {
                    title = LocalizedString("link-action.open-in-default-browser")
                }
                actions.append(.default(title: title) { UIApplication.shared.open(linkURL) })
            }
                    
            if browsers.contains(.chrome) && isHTTP {
                actions.append(.default(title: LocalizedString("link-action.open-in-chrome")) {
                    UIApplication.shared.open(chromifyURL(linkURL))
                })
            }
                    
            if browsers.contains(.firefox) && isHTTP {
                actions.append(.default(title: LocalizedString("link-action.open-in-firefox")) {
                    UIApplication.shared.open(firefoxifyURL(linkURL))
                })
            }

            if browsers.contains(.brave) && isHTTP {
                actions.append(.default(title: LocalizedString("link-action.open-in-brave")) {
                    UIApplication.shared.open(bravifyURL(linkURL))
                })
            }

            if browsers.contains(.edge) && isHTTP {
                actions.append(.default(title: LocalizedString("link-action.open-in-edge")) {
                    UIApplication.shared.open(edgifyURL(linkURL))
                })
            }
            
            actions.append(.default(title: LocalizedString("link-action.copy-url")) {
                UIPasteboard.general.coercedURL = linkURL
            })
            
            actions.append(.default(title: LocalizedString("link-action.share-url")) {
                let objectsToShare = [linkURL]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                presenter.present(activityVC, animated: true)

                if let popover = activityVC.popoverPresentationController {
                    popover.sourceRect = sourceRect
                    popover.sourceView = sourceView
                }
            })

            if let imageURL {
                actions.append(.default(title: LocalizedString("link-action.open-image")) {
                    let preview = ImageViewController(imageURL: imageURL)
                    preview.title = presenter.title
                    presenter.present(preview, animated: true, completion: nil)
                })
                
                actions.append(.default(title: LocalizedString("link-action.copy-image-url")) {
                    UIPasteboard.general.coercedURL = imageURL
                })
            }

            if let smilie {
                if let storedSmilie = SmilieDataStore.shared.fetchSmilie(text: smilie.text) {
                    let format = storedSmilie.metadata.isFavorite ? LocalizedString("smilie-action.remove-from-favorites") : LocalizedString("smilie-action.add-to-favorites")

                    actions.append(.default(title: String(format: format, storedSmilie.text)) {
                        if storedSmilie.metadata.isFavorite {
                            storedSmilie.metadata.removeFromFavoritesUpdatingSubsequentIndices()
                        } else {
                            storedSmilie.metadata.addToFavorites()
                        }
                        try! storedSmilie.managedObjectContext?.save()
                    })
                    message = nil
                } else {
                    message = smilie.text
                }
            } else {
                message = nil
            }

        case let .video(rawURL):
            if let videoURL = VideoURL(rawURL) {
                title = videoURL.unembeddedURL.absoluteString
                message = nil
                actions.append(.default(title: LocalizedString("link-action.open")) {
                    AwfulBrowser.presentBrowserForURL(videoURL.unembeddedURL, fromViewController: presenter)
                })
                actions.append(.default(title: videoURL.actionTitle) {
                    UIApplication.shared.open(videoURL.actionURL)
                })
                actions.append(.default(title: LocalizedString("link-action.share-url")) {
                    let items = [videoURL.unembeddedURL]
                    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    presenter.present(activityVC, animated: true)

                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceRect = sourceRect
                        popover.sourceView = sourceView
                    }
                })
            } else {
                (title, message) = (nil, nil)
                actions.append(.default(title: LocalizedString("link-action.copy-url")) {
                    UIPasteboard.general.coercedURL = rawURL
                })
            }
        }
        
        actions.append(.cancel())
        let alert = UIAlertController(title: title, message: message, actionSheetActions: actions)
        presenter.present(alert, animated: true)

        if let popover = alert.popoverPresentationController {
            popover.sourceRect = sourceRect
            popover.sourceView = sourceView
        }
    }
    
    fileprivate enum VideoURL {
        case vimeo(clipID: String)
        case youTube(v: String)
        
        init?(_ url: URL) {
            let host = url.host?.lowercased()
            if host?.hasSuffix("player.vimeo.com") == true && url.pathComponents.count >= 2 {
                self = .vimeo(clipID: url.lastPathComponent)
            } else if host?.hasSuffix("youtube-nocookie.com") == true && url.pathComponents.count >= 2 {
                self = .youTube(v: url.lastPathComponent)
            } else if host?.hasSuffix("youtube.com") == true && url.path.lowercased().hasPrefix("/embed/") == true {
                self = .youTube(v: url.lastPathComponent)
            } else if host?.hasSuffix("youtu.be") == true {
                // URL shortener for youtube, all of these links should be videos
                self = .youTube(v: url.lastPathComponent)
            } else {
                return nil
            }
        }
        
        var unembeddedURL: URL {
            switch self {
            case let .vimeo(clipID):
                return URL(string: "https://vimeo.com/\(clipID)")!
            case .youTube:
                return appURL
            }
        }
        
        fileprivate var appURL: URL {
            switch self {
            case let .vimeo(clipID):
                return URL(string: "vimeo://videos/\(clipID)")!
            case let .youTube(v):
                return URL(string: "https://www.youtube.com/watch?v=\(v)")!
            }
        }
        
        var appInstalled: Bool {
            switch self {
            case .vimeo: return UIApplication.shared.canOpenURL(URL(string: "vimeo://")!)
            case .youTube: return UIApplication.shared.canOpenURL(URL(string: "youtube://")!)
            }
        }
        
        var actionTitle: String {
            switch self {
            case .vimeo:
                if appInstalled {
                    return LocalizedString("link-action.open-in-vimeo")
                } else {
                    return LocalizedString("link-action.open-in-default-browser")
                }
            case .youTube:
                if appInstalled {
                    return LocalizedString("link-action.open-in-youtube")
                } else {
                    return LocalizedString("link-action.open-in-default-browser")
                }
            }
        }
        
        var actionURL: URL {
            return appInstalled ? appURL : unembeddedURL
        }
    }
}

private func bravifyURL(_ url: URL) -> URL {
    // https://github.com/brave/ios-open-thirdparty-browser
    switch url.scheme?.lowercased() {
    case "http", "https":
        var components = URLComponents(string: "brave://open-url")!
        components.queryItems = [.init(name: "url", value: url.absoluteString)]
        return components.url!
    default:
        Log.w("can't make a Brave URL for url \(url)")
        return url
    }
}

private func chromifyURL(_ url: URL) -> URL {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    if components.scheme?.lowercased() == "http" {
        components.scheme = "googlechrome"
    } else if components.scheme?.lowercased() == "https" {
        components.scheme = "googlechromes"
    }
    return components.url!
}

func downloadVideo(with url: URL, completion: @escaping (URL?) -> ()) {
    URLSession.shared.downloadTask(with: url) { url, response, error in
        guard let tempUrl = url, error == nil else {
            return completion(nil)
        }
  
        let fileManager = FileManager.default
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoFileUrl = documentsUrl.appendingPathComponent(response?.suggestedFilename ?? "temp.mp4")
        
        if fileManager.fileExists(atPath: videoFileUrl.path) {
            try? fileManager.removeItem(at: videoFileUrl)
        }
        do {
            try fileManager.moveItem(at: tempUrl, to: videoFileUrl)
            Log.d("url: \(videoFileUrl)")
            completion(videoFileUrl)
        } catch {
            completion(nil)
        }
    }.resume()
}

func saveToPhotos(_ url: URL, overlay: MRProgressOverlayView?, completion: @escaping (ErrorWorkaround?) -> ()) {
    PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
    }) { saved, error in
        try? FileManager.default.removeItem(at: url)
        DispatchQueue.main.async {
            if saved, error == nil {
                completion(nil)
            } else {
                completion(.unknown)
            }
            overlay?.dismiss(true)
        }
    }
}

func downloadVideoAndSaveToPhotos(_ remoteUrl: URL, renderView: RenderView, completion: @escaping (ErrorWorkaround?) -> ()) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized else {
            return DispatchQueue.main.async {
                completion(.accessDenied)
            }
        }
    }

    let title = LocalizedString("save-action.saving-video")
    let overlay = MRProgressOverlayView.showOverlayAdded(to: renderView, title: title, mode: .indeterminate, animated: true)

    downloadVideo(with: remoteUrl) { videoUrl in
        guard let videoUrl = videoUrl else {
            return DispatchQueue.main.async {
                completion(.unknown)
            }
        }

        saveToPhotos(videoUrl, overlay: overlay) { error in
            completion(error)
        }
    }
}

private func edgifyURL(_ url: URL) -> URL {
    // https://stackoverflow.com/a/51109646
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    if components.scheme?.lowercased() == "http" {
        components.scheme = "microsoft-edge-http"
    } else if components.scheme?.lowercased() == "https" {
        components.scheme = "microsoft-edge-https"
    }
    return components.url!
}

private func firefoxifyURL(_ url: URL) -> URL {
    // https://github.com/mozilla-mobile/firefox-ios-open-in-client
    switch url.scheme?.lowercased() {
    case "http"?, "https"?:
        break
    default:
        Log.w("can't make a Firefox URL for url \(url)")
        return url
    }
    
    let base = URL(string: "firefox://open-url")!
    var components = URLComponents(url: base, resolvingAgainstBaseURL: true)!
    components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
    return components.url!
}

private func canOpenInYouTube(_ url: URL) -> Bool {
    let installed = UIApplication.shared.canOpenURL(URL(string:"youtube://")!)
    let host = url.host?.lowercased()
    let query = url.query?.lowercased()
    let path = url.path.lowercased()
    if installed == true
        && host?.hasSuffix("youtube.com") == true
        && path.hasPrefix("/watch") == true
        && query?.hasPrefix("v=") == true {
            
        return true
    }
    if installed == true
        && host?.hasSuffix("youtu.be") == true {
            return true
    }
    return false
}

private func canOpenInVLC(_ url: URL) -> Bool {
    let installed = UIApplication.shared.canOpenURL(URL(string:"vlc://")!)
    let path = url.path.lowercased()
    if installed == true
        && path.hasSuffix(".webm") == true {
            return true
    }
    return false
}

private func canOpenInTwitter(_ url: URL) -> Bool {
    let installed = UIApplication.shared.canOpenURL(URL(string: "twitter://")!)
    let host = url.host?.lowercased()
    if installed == true && host?.hasSuffix("twitter.com") == true {
        return true
    }
    return false
}

/// Presents a menu for a link or a video.
final class URLMenuPresenter: NSObject {
    
    fileprivate let menuPresenter: _URLMenuPresenter
    
    init(linkURL: URL, imageURL: URL? = nil, smilie: PostedSmilie? = nil) {
        menuPresenter = .link(url: linkURL, imageURL: imageURL, smilie: smilie)
        super.init()
    }
    
    init(videoURL: URL) {
        menuPresenter = .video(url: videoURL)
        super.init()
    }
    
    func presentInDefaultBrowser(fromViewController presenter: UIViewController) {
        menuPresenter.presentInDefaultBrowser(fromViewController: presenter)
    }
    
    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: UIView) {
        menuPresenter.present(fromViewController: presenter, fromRect: sourceRect, inView: sourceView)
    }
    
    // Convenience function.
    class func presentInterestingElements(_ elements: [RenderView.InterestingElement], from presentingViewController: UIViewController, renderView: RenderView) -> Bool {
        var imageFrame: CGRect?
        var imageURL: URL?
        var smilie: PostedSmilie?
        for case let .spoiledImage(title: title, url: url, frame: frame, location: location) in elements {
            if case .postbody? = location {
                smilie = PostedSmilie(title: title, url: url)
            }
            imageURL = URL(string: url.absoluteString, relativeTo: ForumsClient.shared.baseURL)
            imageFrame = frame
            break
        }
        
        for case let .spoiledLink(frame: frame, url: unresolved) in elements {
            if let resolved = URL(string: unresolved.absoluteString, relativeTo: ForumsClient.shared.baseURL) {
                let presenter = URLMenuPresenter(linkURL: resolved, imageURL: imageURL, smilie: smilie)
                presenter.present(fromViewController: presentingViewController, fromRect: frame, inView: renderView)
                return true
            }
        }

        if let smilie = smilie {
            // Just a smilie, nothing else.
            var actions: [UIAlertAction] = []
            if let storedSmilie = SmilieDataStore.shared.fetchSmilie(text: smilie.text) {
                let format = storedSmilie.metadata.isFavorite ? LocalizedString("smilie-action.remove-from-favorites") : LocalizedString("smilie-action.add-to-favorites")

                actions.append(.default(title: String(format: format, storedSmilie.text)) {
                    if storedSmilie.metadata.isFavorite {
                        storedSmilie.metadata.removeFromFavoritesUpdatingSubsequentIndices()
                    } else {
                        storedSmilie.metadata.addToFavorites()
                    }
                    try! storedSmilie.managedObjectContext?.save()
                })
            }

            if let imageURL = imageURL {
                actions.append(.default(title: LocalizedString("link-action.open-image")) {
                    let preview = ImageViewController(imageURL: imageURL)
                    preview.title = presentingViewController.title
                    presentingViewController.present(preview, animated: true)
                })
            }

            actions.append(.cancel())
            let actionSheet = UIAlertController(message: smilie.text, actionSheetActions: actions)
            presentingViewController.present(actionSheet, animated: true)

            if let popover = actionSheet.popoverPresentationController {
                if let imageFrame {
                    popover.sourceRect = imageFrame.insetBy(dx: -6, dy: -6)
                }
                popover.sourceView = renderView
            }
        } else if let imageURL = imageURL {
            let preview = ImageViewController(imageURL: imageURL)
            preview.title = presentingViewController.title
            presentingViewController.present(preview, animated: true)
            return true
        }
        
        for case let .spoiledVideo(frame: frame, url: unresolved) in elements {
            if let resolved = URL(string: unresolved.absoluteString, relativeTo: ForumsClient.shared.baseURL) {
                let path = resolved.path.lowercased()
                if path.hasSuffix(".mp4") {
                    var actions: [UIAlertAction] = []
                    actions.append(.default(title: LocalizedString("link-action.copy-url")) {
                        UIPasteboard.general.coercedURL = resolved
                    })
                    
                    switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
                    case .authorized, .limited, .notDetermined:
                        actions.append(.default(title: LocalizedString("save-action.save-video")) {
                            downloadVideoAndSaveToPhotos(resolved, renderView: renderView) { error in
                                if let error = error {
                                    DispatchQueue.main.async {
                                        let alert = UIAlertController(title: LocalizedString("save-action.error"),
                                                                      message: LocalizedString("save-action.error_description"),
                                                                      preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                        
                                        presentingViewController.present(alert, animated: true)
                                    }
                                    Log.d("Save video error: \(error)")
                                } else {
                                    DispatchQueue.main.async {
                                        let alert = UIAlertController(title: LocalizedString("save-action.success"),
                                                                      message: "",
                                                                      preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                                        presentingViewController.present(alert, animated: true)
                                    }
                                    Log.d("Save video Success")
                                }
                            }
                        })
                    case .denied, .restricted:
                        break
                    @unknown default:
                        break
                    }
                    actions.append(.cancel())
                    let actionSheet = UIAlertController(actionSheetActions: actions)
                    presentingViewController.present(actionSheet, animated: true)
                    actionSheet.popoverPresentationController?.sourceRect = frame
                    actionSheet.popoverPresentationController?.sourceView = renderView
                } else {
                    let presenter = URLMenuPresenter(videoURL: resolved)
                    presenter.present(fromViewController: presentingViewController, fromRect: frame, inView: renderView)
                }
                return true
            }
        }
        return false
    }
}

enum ErrorWorkaround {
    case accessDenied
    case unknown
}
