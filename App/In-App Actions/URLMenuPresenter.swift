//  URLMenuPresenter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private enum _URLMenuPresenter {
    case Link(URL: NSURL, imageURL: NSURL?)
    case Video(URL: NSURL)
    
    func presentInDefaultBrowser(fromViewController presenter: UIViewController) {
        var URL: NSURL
        switch self {
        case .Link(let linkURL, _):
            URL = linkURL
        case .Video(let rawURL):
            if let videoURL = VideoURL(rawURL) {
                URL = videoURL.unembeddedURL
            } else {
                URL = rawURL
            }
        }
        
        let browser = AwfulSettings.sharedSettings().defaultBrowser
        switch browser {
        case AwfulDefaultBrowserAwful:
            YABrowserViewController.presentBrowserForURL(URL, fromViewController: presenter)
        case AwfulDefaultBrowserSafari:
            UIApplication.sharedApplication().openURL(URL)
        case AwfulDefaultBrowserChrome:
            UIApplication.sharedApplication().openURL(chromifyURL(URL))
        default:
            fatalError("unexpected browser \(browser)")
        }
    }
    
    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: UIView) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        switch self {
        case let .Link(linkURL, imageURL):
            alert.title = linkURL.absoluteString
            
            let nonDefaultBrowsers = (AwfulDefaultBrowsers() as! [String]).filter { $0 != AwfulSettings.sharedSettings().defaultBrowser }
            for browser in nonDefaultBrowsers {
                switch browser {
                case AwfulDefaultBrowserAwful:
                    alert.addAction(UIAlertAction(title: "Open in Awful", style: .Default, handler: { _ in
                        YABrowserViewController.presentBrowserForURL(linkURL, fromViewController: presenter)
                        return
                    }))
                    
                case AwfulDefaultBrowserSafari:
                    alert.addAction(UIAlertAction(title: "Open in Safari", style: .Default, handler: { _ in
                        UIApplication.sharedApplication().openURL(linkURL)
                        return
                    }))
                    
                case AwfulDefaultBrowserChrome:
                    alert.addAction(UIAlertAction(title: "Open in Chrome", style: .Default, handler: { _ in
                        UIApplication.sharedApplication().openURL(chromifyURL(linkURL))
                        return
                    }))
                    
                default:
                    fatalError("unexpected browser \(browser)")
                }
            }
            
            alert.addAction(UIAlertAction(title: "Copy URL", style: .Default, handler: { _ in
                UIPasteboard.generalPasteboard().awful_URL = linkURL
            }))
            
            if let imageURL = imageURL {
                alert.addAction(UIAlertAction(title: "Open Image", style: .Default, handler: { _ in
                    let preview = ImageViewController(imageURL: imageURL)
                    preview.title = presenter.title
                    presenter.presentViewController(preview, animated: true, completion: nil)
                }))
                
                alert.addAction(UIAlertAction(title: "Copy Image URL", style: .Default, handler: { _ in
                    UIPasteboard.generalPasteboard().awful_URL = imageURL
                }))
            }
            
        case let .Video(rawURL):
            if let videoURL = VideoURL(rawURL) {
                alert.title = videoURL.unembeddedURL.absoluteString
                alert.addAction(UIAlertAction(title: "Open", style: .Default, handler: { _ in
                    YABrowserViewController.presentBrowserForURL(videoURL.unembeddedURL, fromViewController: presenter)
                    return
                }))
                alert.addAction(UIAlertAction(title: videoURL.actionTitle, style: .Default, handler: { _ in
                    UIApplication.sharedApplication().openURL(videoURL.actionURL)
                    return
                }))
                alert.addAction(UIAlertAction(title: "Copy URL", style: .Default, handler: { _ in
                    UIPasteboard.generalPasteboard().awful_URL = videoURL.unembeddedURL
                }))
            } else {
                alert.addAction(UIAlertAction(title: "Copy URL", style: .Default, handler: { _ in
                    UIPasteboard.generalPasteboard().awful_URL = rawURL
                }))
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        presenter.presentViewController(alert, animated: true, completion: nil)
        if let popover = alert.popoverPresentationController {
            popover.sourceRect = sourceRect
            popover.sourceView = sourceView
        }
    }
    
    private enum VideoURL {
        case Vimeo(clipID: String)
        case YouTube(v: String)
        
        init?(_ URL: NSURL) {
            let host = URL.host?.lowercaseString
            if host?.hasSuffix("player.vimeo.com") == true && URL.pathComponents?.count >= 2 {
                self = .Vimeo(clipID: URL.lastPathComponent!)
            } else if host?.hasSuffix("youtube-nocookie.com") == true && URL.pathComponents?.count >= 2 {
                self = .YouTube(v: URL.lastPathComponent!)
            } else if host?.hasSuffix("youtube.com") == true && URL.path?.lowercaseString.hasPrefix("/embed/") == true {
                self = .YouTube(v: URL.lastPathComponent!)
            } else {
                return nil
            }
        }
        
        var unembeddedURL: NSURL {
            switch self {
            case let .Vimeo(clipID):
                return NSURL(string: "http://vimeo.com/\(clipID)")!
            case .YouTube:
                return appURL
            }
        }
        
        private var appURL: NSURL {
            switch self {
            case let .Vimeo(clipID):
                return NSURL(string: "vimeo://videos/\(clipID)")!
            case let .YouTube(v):
                return NSURL(string: "http://www.youtube.com/watch?v=\(v)")!
            }
        }
        
        var appInstalled: Bool {
            switch self {
            case .Vimeo: return UIApplication.sharedApplication().canOpenURL(NSURL(string: "vimeo://")!)
            case .YouTube: return UIApplication.sharedApplication().canOpenURL(NSURL(string: "youtube://")!)
            }
        }
        
        var actionTitle: String {
            switch self {
            case let .Vimeo:
                let app = appInstalled ? "Vimeo" : "Safari"
                return "Open in \(app)"
            case let .YouTube:
                let app = appInstalled ? "YouTube" : "Safari"
                return "Open in \(app)"
            }
        }
        
        var actionURL: NSURL {
            return appInstalled ? appURL : unembeddedURL
        }
    }
}

private func chromifyURL(URL: NSURL) -> NSURL {
    let components = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)!
    if components.scheme?.lowercaseString == "http" {
        components.scheme = "googlechrome"
    } else if components.scheme?.lowercaseString == "https" {
        components.scheme = "googlechromes"
    }
    return components.URL!
}

/// Presents a menu for a link or a video.
final class URLMenuPresenter: NSObject {
    private let menuPresenter: _URLMenuPresenter
    
    init(linkURL: NSURL, imageURL: NSURL? = nil) {
        menuPresenter = .Link(URL: linkURL, imageURL: imageURL)
        super.init()
    }
    
    init(videoURL: NSURL) {
        menuPresenter = .Video(URL: videoURL)
        super.init()
    }
    
    func presentInDefaultBrowser(fromViewController presenter: UIViewController) {
        menuPresenter.presentInDefaultBrowser(fromViewController: presenter)
    }
    
    func present(fromViewController presenter: UIViewController, fromRect sourceRect: CGRect, inView sourceView: UIView) {
        menuPresenter.present(fromViewController: presenter, fromRect: sourceRect, inView: sourceView)
    }
}
