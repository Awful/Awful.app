//  URLMenuPresenter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


private enum _URLMenuPresenter {
    case link(url: URL, imageURL: URL?)
    case video(url: URL)
    
    func presentInDefaultBrowser(fromViewController presenter: UIViewController) {
        let url: URL
        switch self {
        case .link(let linkURL, _):
            url = linkURL
        case .video(let rawURL):
            if let videoURL = VideoURL(rawURL) {
                url = videoURL.unembeddedURL
            } else {
                url = rawURL
            }
        }
        
        if canOpenInYouTube(url) &&
            AwfulSettings.shared().openYouTubeLinksInYouTube {
            
            UIApplication.shared.openURL(url)
            return
        }
        
        if canOpenInTwitter(url) &&
            AwfulSettings.shared().openTwitterLinksInTwitter {
            UIApplication.shared.openURL(url)
            return
        }
        
        if canOpenInVLC(url) {
            let vlcURL = URL(string: "vlc://\(url.host!)\(url.path)")!
            UIApplication.shared.openURL(vlcURL)
            return
        }
        
        let browser = AwfulSettings.shared().defaultBrowser
        switch browser {
        case AwfulDefaultBrowserAwful?:
            AwfulBrowser.presentBrowserForURL(url, fromViewController: presenter)
        case AwfulDefaultBrowserSafari?:
            UIApplication.shared.openURL(url)
        case AwfulDefaultBrowserChrome?:
            UIApplication.shared.openURL(chromifyURL(url))
        default:
            fatalError("unexpected browser \(browser)")
        }
    }
    
    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: UIView) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        switch self {
        case let .link(linkURL, imageURL):
            alert.title = linkURL.absoluteString
            
            let nonDefaultBrowsers = (AwfulDefaultBrowsers() as! [String]).filter { $0 != AwfulSettings.shared().defaultBrowser }
            for browser in nonDefaultBrowsers {
                switch browser {
                case AwfulDefaultBrowserAwful:
                    alert.addAction(UIAlertAction(title: "Open in Awful", style: .default, handler: { _ in
                        let _ = AwfulBrowser.presentBrowserForURL(linkURL, fromViewController: presenter)
                        return
                    }))
                    
                case AwfulDefaultBrowserSafari:
                    let title: String
                    if canOpenInYouTube(linkURL) {
                        title = "Open in YouTube"
                    } else if canOpenInTwitter(linkURL) {
                        title = "Open in Twitter"
                    } else {
                        title = "Open in Safari"
                    }
                    alert.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
                        UIApplication.shared.openURL(linkURL)
                        return
                    }))
                    
                case AwfulDefaultBrowserChrome:
                    alert.addAction(UIAlertAction(title: "Open in Chrome", style: .default, handler: { _ in
                        UIApplication.shared.openURL(chromifyURL(linkURL))
                        return
                    }))
                    
                default:
                    fatalError("unexpected browser \(browser)")
                }
            }
            
            alert.addAction(UIAlertAction(title: "Copy URL", style: .default, handler: { _ in
                UIPasteboard.general.awful_URL = linkURL
            }))
            
            alert.addAction(UIAlertAction(title: "Share URL", style: .default, handler: { _ in
                let objectsToShare = [linkURL]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                
                presenter.present(activityVC, animated: true, completion: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceRect = sourceRect
                    popover.sourceView = sourceView
                }
                
            }))
            
            
            if let imageURL = imageURL {
                alert.addAction(UIAlertAction(title: "Open Image", style: .default, handler: { _ in
                    let preview = ImageViewController(imageURL: imageURL)
                    preview.title = presenter.title
                    presenter.present(preview, animated: true, completion: nil)
                }))
                
                alert.addAction(UIAlertAction(title: "Copy Image URL", style: .default, handler: { _ in
                    UIPasteboard.general.awful_URL = imageURL
                }))
            }
            
            

            
        case let .video(rawURL):
            if let videoURL = VideoURL(rawURL) {
                alert.title = videoURL.unembeddedURL.absoluteString
                alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { _ in
                    AwfulBrowser.presentBrowserForURL(videoURL.unembeddedURL, fromViewController: presenter)
                    return
                }))
                alert.addAction(UIAlertAction(title: videoURL.actionTitle, style: .default, handler: { _ in
                    UIApplication.shared.openURL(videoURL.actionURL)
                    return
                }))
                alert.addAction(UIAlertAction(title: "Copy URL", style: .default, handler: { _ in
                    UIPasteboard.general.awful_URL = videoURL.unembeddedURL
                }))
            } else {
                alert.addAction(UIAlertAction(title: "Copy URL", style: .default, handler: { _ in
                    UIPasteboard.general.awful_URL = rawURL
                }))
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        presenter.present(alert, animated: true, completion: nil)
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
                return URL(string: "http://vimeo.com/\(clipID)")!
            case .youTube:
                return appURL
            }
        }
        
        fileprivate var appURL: URL {
            switch self {
            case let .vimeo(clipID):
                return URL(string: "vimeo://videos/\(clipID)")!
            case let .youTube(v):
                return URL(string: "http://www.youtube.com/watch?v=\(v)")!
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
                let app = appInstalled ? "Vimeo" : "Safari"
                return "Open in \(app)"
            case .youTube:
                let app = appInstalled ? "YouTube" : "Safari"
                return "Open in \(app)"
            }
        }
        
        var actionURL: URL {
            return appInstalled ? appURL : unembeddedURL
        }
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
    
    init(linkURL: URL, imageURL: URL? = nil) {
        menuPresenter = .link(url: linkURL, imageURL: imageURL)
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
}
