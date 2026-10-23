//  URLMenuPresenter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import MRProgress
import os
import Photos
import Smilies
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "URLMenuPresenter")

/// One entry in a menu, independent of how the menu is drawn.
private struct MenuItem {
    let title: String
    let handler: () -> Void
}

/// Draws the items as an action sheet or as a native menu anchored to `sourceRect` in `sourceView`.
private func presentMenu(_ items: [MenuItem], title: String?, message: String? = nil, style: URLMenuPresenter.Style, from presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: RenderView) {
    switch style {
    case .actionSheet:
        var actions = items.map { item in UIAlertAction.default(title: item.title, handler: item.handler) }
        actions.append(.cancel())
        let alert = UIAlertController(title: title, message: message, actionSheetActions: actions)
        // Anchor before presenting: on the Mac the popover reads its anchor as presentation starts.
        if let popover = alert.popoverPresentationController {
            popover.sourceRect = sourceRect
            popover.sourceView = sourceView
        }
        presenter.present(alert, animated: true)

    case let .contextMenu(at: point):
        let actions = items.map { item in UIAction(title: item.title) { _ in item.handler() } }
        let menu = UIMenu(title: title ?? "", subtitle: message, children: actions)
        // Drop down from the cursor, as a Mac menu does, rather than from the element's frame.
        let anchor = CGRect(origin: point, size: .zero).insetBy(dx: -1, dy: -1)
        sourceView.showMenu(menu, from: anchor)
    }
}

/// Adds or removes the smilie from favorites, when it's one the app knows.
private func smilieFavoriteItem(for smilie: PostedSmilie) -> MenuItem? {
    guard let storedSmilie = SmilieDataStore.shared.fetchSmilie(text: smilie.text) else { return nil }
    let format = storedSmilie.metadata.isFavorite ? LocalizedString("smilie-action.remove-from-favorites") : LocalizedString("smilie-action.add-to-favorites")
    return MenuItem(title: String(format: format, storedSmilie.text)) {
        if storedSmilie.metadata.isFavorite {
            storedSmilie.metadata.removeFromFavoritesUpdatingSubsequentIndices()
        } else {
            storedSmilie.metadata.addToFavorites()
        }
        try! storedSmilie.managedObjectContext?.save()
    }
}

private func openImage(_ imageURL: URL, from presenter: UIViewController) {
    let preview = ImageViewController(imageURL: imageURL)
    preview.title = presenter.title
    presenter.present(preview, animated: true)
}

private func shareURL(_ url: URL, from presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: UIView) {
    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = activityVC.popoverPresentationController {
        popover.sourceRect = sourceRect
        popover.sourceView = sourceView
    }
    presenter.present(activityVC, animated: true)
}

/// Copy Image and Save Image for an image we only know the URL of. The web view's copy of the bytes isn't reachable from here, so they come from a fresh download.
private func imageDataItems(for imageURL: URL, presenter: UIViewController) -> [MenuItem] {
    var items: [MenuItem] = []

    items.append(MenuItem(title: LocalizedString("link-action.copy-image")) {
        Task { @MainActor in
            do {
                let data = try await fetchImageData(imageURL)
                guard copyImageToPasteboard(data) else { throw ImageActionError.notAnImage }
            } catch {
                presentImageActionError(error, from: presenter)
            }
        }
    })

    switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
    case .authorized, .limited, .notDetermined:
        items.append(MenuItem(title: LocalizedString("link-action.save-image")) {
            Task { @MainActor in
                do {
                    let data = try await fetchImageData(imageURL)
                    guard imageUTI(data) != nil else { throw ImageActionError.notAnImage }
                    try await saveImageToPhotos(data)
                } catch {
                    presentImageActionError(error, from: presenter)
                }
            }
        })
    case .denied, .restricted:
        break
    @unknown default:
        break
    }

    return items
}

private enum ImageActionError: LocalizedError {
    case notAnImage
    case photosAccessDenied

    var errorDescription: String? {
        switch self {
        case .notAnImage: return LocalizedString("image-action.error.not-an-image")
        case .photosAccessDenied: return LocalizedString("image-action.error.photos-access")
        }
    }
}

private func fetchImageData(_ url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.addValue("image/*", forHTTPHeaderField: "Accept")
    let (data, response) = try await URLSession.shared.data(for: request)
    if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
        throw URLError(.badServerResponse)
    }
    return data
}

/// Adds the image to the photo library as-is, so GIFs stay animated.
private func saveImageToPhotos(_ data: Data) async throws {
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else { throw ImageActionError.photosAccessDenied }
    try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
    }
}

@MainActor
private func presentImageActionError(_ error: Error, from presenter: UIViewController) {
    logger.error("image action failed: \(error)")
    let alert = UIAlertController(title: LocalizedString("save-action.error"), message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(.ok())
    presenter.present(alert, animated: true)
}

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
    
    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: RenderView, style: URLMenuPresenter.Style) {
        var items: [MenuItem] = []
        let title: String?
        let message: String?
        switch self {
        case let .link(url: linkURL, imageURL: imageURL, smilie: smilie):
            title = linkURL.absoluteString

            let browsers = DefaultBrowser.installedBrowsers
            let isHTTP = ["http", "https"].contains((linkURL.scheme ?? "").lowercased())
            let route = try? AwfulRoute(linkURL)
            
            if browsers.contains(.awful) && (route != nil || isHTTP) {
                items.append(MenuItem(title: LocalizedString("link-action.open-in-awful")) {
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
                items.append(MenuItem(title: title) { UIApplication.shared.open(linkURL) })
            }
                    
            if browsers.contains(.chrome) && isHTTP {
                items.append(MenuItem(title: LocalizedString("link-action.open-in-chrome")) {
                    UIApplication.shared.open(chromifyURL(linkURL))
                })
            }
                    
            if browsers.contains(.firefox) && isHTTP {
                items.append(MenuItem(title: LocalizedString("link-action.open-in-firefox")) {
                    UIApplication.shared.open(firefoxifyURL(linkURL))
                })
            }

            if browsers.contains(.brave) && isHTTP {
                items.append(MenuItem(title: LocalizedString("link-action.open-in-brave")) {
                    UIApplication.shared.open(bravifyURL(linkURL))
                })
            }

            if browsers.contains(.edge) && isHTTP {
                items.append(MenuItem(title: LocalizedString("link-action.open-in-edge")) {
                    UIApplication.shared.open(edgifyURL(linkURL))
                })
            }
            
            items.append(MenuItem(title: LocalizedString("link-action.copy-url")) {
                UIPasteboard.general.coercedURL = linkURL
            })
            
            items.append(MenuItem(title: LocalizedString("link-action.share-url")) {
                shareURL(linkURL, from: presenter, fromRect: sourceRect, inView: sourceView)
            })

            if let imageURL {
                items.append(MenuItem(title: LocalizedString("link-action.open-image")) {
                    openImage(imageURL, from: presenter)
                })
                
                items.append(MenuItem(title: LocalizedString("link-action.copy-image-url")) {
                    UIPasteboard.general.coercedURL = imageURL
                })

                items += imageDataItems(for: imageURL, presenter: presenter)
            }

            if let smilie, let favorite = smilieFavoriteItem(for: smilie) {
                items.append(favorite)
                message = nil
            } else {
                message = smilie?.text
            }

        case let .video(rawURL):
            if let videoURL = VideoURL(rawURL) {
                title = videoURL.unembeddedURL.absoluteString
                message = nil
                items.append(MenuItem(title: LocalizedString("link-action.open")) {
                    AwfulBrowser.presentBrowserForURL(videoURL.unembeddedURL, fromViewController: presenter)
                })
                items.append(MenuItem(title: videoURL.actionTitle) {
                    UIApplication.shared.open(videoURL.actionURL)
                })
                items.append(MenuItem(title: LocalizedString("link-action.share-url")) {
                    shareURL(videoURL.unembeddedURL, from: presenter, fromRect: sourceRect, inView: sourceView)
                })
            } else {
                (title, message) = (nil, nil)
                items.append(MenuItem(title: LocalizedString("link-action.copy-url")) {
                    UIPasteboard.general.coercedURL = rawURL
                })
            }
        }
        
        presentMenu(items, title: title, message: message, style: style, from: presenter, fromRect: sourceRect, inView: sourceView)
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
        logger.warning("can't make a Brave URL for url \(url)")
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
            logger.debug("url: \(videoFileUrl)")
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
        logger.warning("can't make a Firefox URL for url \(url)")
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
    
    /// How a menu is drawn. A long press on iOS gets the usual action sheet. A right-click gets a native menu, like the one the system would show, dropping down from the click (a point in the source view's coordinates).
    enum Style {
        case actionSheet
        case contextMenu(at: CGPoint)
    }

    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: RenderView, style: Style = .actionSheet) {
        menuPresenter.present(fromViewController: presenter, fromRect: sourceRect, inView: sourceView, style: style)
    }
    
    /// Presents whatever menu suits the elements. A long press (`.actionSheet`) on an image that isn't a link opens the image viewer with no menu, as iOS always has; a right-click (`.contextMenu`) gets a menu for it instead.
    class func presentInterestingElements(_ elements: [RenderView.InterestingElement], from presentingViewController: UIViewController, renderView: RenderView, style: Style = .actionSheet) -> Bool {
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
                presenter.present(fromViewController: presentingViewController, fromRect: frame, inView: renderView, style: style)
                return true
            }
        }

        let imageRect = imageFrame?.insetBy(dx: -6, dy: -6) ?? renderView.bounds

        if let smilie {
            // Just a smilie, nothing else.
            var items: [MenuItem] = []
            if let favorite = smilieFavoriteItem(for: smilie) {
                items.append(favorite)
            }

            if let imageURL {
                items.append(MenuItem(title: LocalizedString("link-action.open-image")) {
                    openImage(imageURL, from: presentingViewController)
                })
            }

            presentMenu(items, title: nil, message: smilie.text, style: style, from: presentingViewController, fromRect: imageRect, inView: renderView)
            return true
        } else if let imageURL {
            if case .actionSheet = style {
                openImage(imageURL, from: presentingViewController)
                return true
            }

            var items: [MenuItem] = []
            items.append(MenuItem(title: LocalizedString("link-action.open-image")) {
                openImage(imageURL, from: presentingViewController)
            })
            items.append(MenuItem(title: LocalizedString("link-action.copy-image-url")) {
                UIPasteboard.general.coercedURL = imageURL
            })
            items += imageDataItems(for: imageURL, presenter: presentingViewController)
            items.append(MenuItem(title: LocalizedString("link-action.share-url")) {
                shareURL(imageURL, from: presentingViewController, fromRect: imageRect, inView: renderView)
            })
            presentMenu(items, title: imageURL.absoluteString, style: style, from: presentingViewController, fromRect: imageRect, inView: renderView)
            return true
        }
        
        for case let .spoiledVideo(frame: frame, url: unresolved) in elements {
            if let resolved = URL(string: unresolved.absoluteString, relativeTo: ForumsClient.shared.baseURL) {
                let path = resolved.path.lowercased()
                if path.hasSuffix(".mp4") {
                    var items: [MenuItem] = []
                    items.append(MenuItem(title: LocalizedString("link-action.copy-url")) {
                        UIPasteboard.general.coercedURL = resolved
                    })
                    
                    switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
                    case .authorized, .limited, .notDetermined:
                        items.append(MenuItem(title: LocalizedString("save-action.save-video")) {
                            downloadVideoAndSaveToPhotos(resolved, renderView: renderView) { error in
                                if let error = error {
                                    DispatchQueue.main.async {
                                        let alert = UIAlertController(title: LocalizedString("save-action.error"),
                                                                      message: LocalizedString("save-action.error_description"),
                                                                      preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                        
                                        presentingViewController.present(alert, animated: true)
                                    }
                                    let description = "\(error)"
                                    logger.debug("Save video error: \(description)")
                                } else {
                                    DispatchQueue.main.async {
                                        let alert = UIAlertController(title: LocalizedString("save-action.success"),
                                                                      message: "",
                                                                      preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                                        presentingViewController.present(alert, animated: true)
                                    }
                                    logger.debug("Save video Success")
                                }
                            }
                        })
                    case .denied, .restricted:
                        break
                    @unknown default:
                        break
                    }
                    presentMenu(items, title: nil, style: style, from: presentingViewController, fromRect: frame, inView: renderView)
                } else {
                    let presenter = URLMenuPresenter(videoURL: resolved)
                    presenter.present(fromViewController: presentingViewController, fromRect: frame, inView: renderView, style: style)
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
